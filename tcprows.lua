#!/usr/bin/env lem
local cmd = require 'lem.cmd'
local io  = require 'lem.io'

local args = {
  last_arg = "[url] [bind | connect]",
  intro = [[
tcprows -- TCP Relay Over WebSocket, is a tool to relay tcp connection over WebSocket

basic server usage:
  tcprows -s 'http://*:8888/ws-relay' localhost:22
basic client usage:
  tcprows -c 'http://remote_server:8888/ws-relay' localhost:2222

This program support http_proxy / https_proxy environment variables.

Available options are:
]],
  possible = {
    {'h', 'help',              {desc="display this",  type='counter'}},
    {'s', 'server',            {desc="server mode",   type='counter'}},
    {'c', 'client',            {desc="client mode",   type='counter'}},
    {'i', 'info-debug-level',  {desc="set info/debug lvl, 1 10",   default_value=1}},
    {'w', 'websocket-keep-alive',        {desc="send websocket ping every X sec, when no data get transmitted", default_value=30}},
  },
}

local parg = cmd.parse_arg(args, arg)

if parg:is_flag_set('help') then
  cmd.display_usage(args, parg)
end

local g_url = parg.last_arg[0]
local g_bind_connect = parg.last_arg[1]
local g_mode

if parg:is_flag_set('server') then
  g_mode = 'server'
end

if parg:is_flag_set('client') then
  g_mode = 'client'
end

if g_mode == nil then
  io.stderr:write("need to specify client or server mode\n")
  os.exit(1)
end

if g_url == nil then
  io.stderr:write("need to specify an uri to listen or connect\n")
  os.exit(1)
end

local g_debug_lvl = tonumber(parg:get_last_val('info-debug-level'))
local g_websocket_keep_alive = tonumber(parg:get_last_val('websocket-keep-alive'))
local g_debug_normal = 1
local g_debug_verbose = 10

if g_bind_connect == nil then
  io.stderr:write("need to specify bind|connect address\n")
  os.exit(1)
end

local g_hostname, g_port = g_bind_connect:match("^([^:]*):([0-9]*)$")

if g_hostname == nil or g_port == nil then
  io.stderr:write("bind|connect argument need to be of this format: localhost:2222 or 1.2.3.4:22\n")
  os.exit(1)
end
  
-- do we need a proxy to connect outside ?
local g_http_proxy = os.getenv('http_proxy')
local g_https_proxy = os.getenv('https_proxy')


local utils  = require 'lem.utils'
local websocket = require 'lem.websocket.handler'
local mbedtls = require 'lem.mbedtls'

local spawn = utils.spawn
local utils_now = utils.now
local sleep = utils.sleep
local format = string.format

function dbg_p(lvl, raw_or_format, ...)
  if lvl <= g_debug_lvl then
    local now = format("%.4f", utils_now())

    if select('#', ...) == 0 then
      if raw_or_format:find("\n") then
        io.stderr:write(raw_or_format:gsub("([^\n]+\n)",  now ..' > %1'))
      else
        io.stderr:write(now ..' > '..raw_or_format, "\n")
      end
    else
      io.stderr:write(now ..' > '..format(raw_or_format, ...), "\n")
    end
  end
end

function tunnel_ws_sock(res, sock) -- %{
  local last_ws_read = utils_now()
  local closed = false

  function close_all()
    if closed == false then
      sock:close()
      res:close()
      closed = true
    end
  end

  spawn(function ()
    local ok, err
    while true do
      if last_ws_read + g_websocket_keep_alive < utils_now() then
        ok, err = res:ping()
        if ok == nil then
          dbg_p(g_debug_verbose, "ws timeout.. ")
          break
        end

        last_ws_read = utils_now()
      end
      sleep(1)
    end
    close_all()
  end)

  spawn(function ()
    local buf, err 
    while true do
      buf, err = sock:read()
      if buf == nil then
        dbg_p(g_debug_verbose, "socket error: %s", err)
        break
      end
      res:sendBinary(buf)
    end
    close_all()
  end)

  while true do
    err, payload = res:getFrame()
    last_ws_read = utils_now()
    if err then
      dbg_p(g_debug_verbose, "websocket error: %d %s", err, payload)
      break
    end
    sock:write(payload)
  end
  close_all()
end -- }%

function client_mode() -- %{
  local sock = io.tcp.listen(g_hostname, g_port)

  local ssl_conf = {
    mode='client',
    ssl_verify_mode=0,
  }

  local g_sslconfig, err = mbedtls.new_tls_config(ssl_conf)

  print('waiting for connection on '.. g_bind_connect .. " to tunnel to " .. g_url)
  print('http proxy?', g_http_proxy, 'https proxy?', g_https_proxy)

  print("create a remote tunnel to the gateway")
  print("ssh -N -p " .. g_port .. " ar@localhost -R '*:2222:127.0.0.1:22'")

  sock:autospawn(function (client)
    local res, err = websocket.client({
      url=g_url,
      req={http_proxy=g_http_proxy, https_proxy=g_https_proxy},
      ssl=g_sslconfig
    })

    if err then
      dbg_p(g_debug_normal, "can't open websocket: " .. g_url )
      dbg_p(g_debug_normal, table.concat(err,'\t'))
      client:close()
      return 
    end

    tunnel_ws_sock(res, client)
end)

end -- }%

function server_mode() -- %{
  local hathaway = require 'lem.hathaway'

  hathaway.debug = function (...) dbg_p(g_debug_normal, table.concat({...}, "\t")) end
  hathaway.import()

  local proto, domain_and_port, path = g_url:match('([a-zA-Z0-9]+)://([^/]+)(/.*)')
  local listen_domain, listen_port = domain_and_port:match("^([^:]*):([0-9]*)$")

  GET(path, function (req, res)
    local err, err_msg = websocket.serverHandler(req, res)

    if err ~= nil then
      res.status = 400
      res.headers['Content-Type'] = 'text/plain'
      res:add('Websocket Failure!\n' .. err .. "\n")
      return 
    end

    local payload
    local client, err = io.tcp.connect(g_hostname, g_port)
    if client == nil then
      dbg_p(g_debug_normal,"could not connect to %s %s", g_bind_connect, err)
      res:close()
      return 
    end
    tunnel_ws_sock(res, client)
  end)

  print('waiting for connection on ' .. domain_and_port)
  Hathaway(listen_domain, listen_port)
end -- }%

_G[g_mode .. '_mode']()
