local stdout
do
  -- Add current script path to the lua package search path,
  -- this is necessary to require modules relative to this file.
  local script_path = debug.getinfo(1, 'S').source:sub(2)
  local script_dir = script_path:gsub('[/\\]*[^/\\]-$', '')
  script_dir = script_dir == '' and '.' or script_dir
  local dirsep, pathsep = package.config:match('(.)[\r\n]+(.)[\r\n]+')
  package.path = script_dir..dirsep..'?.lua'..pathsep..package.path

  -- Redirect stderr/stdout to a file so we can debug errors.
  local out = io.open(script_dir..dirsep..'stderr.log', 'a')
  assert(out, 'failed to redirect stdout/stderr!')
  stdout = io.stdout
  _G.io.stdout, _G.io.stderr = out, out
end

-- Required modules
local except = require 'nelua.utils.except'
local fs = require 'nelua.utils.fs'
local sstream = require 'nelua.utils.sstream'
local analyzer = require 'nelua.analyzer'
local console  = require 'nelua.utils.console'
local utils = require 'utils'
local syntax = require 'nelua.syntaxdefs'()
local AnalyzerContext = require 'nelua.analyzercontext'
local server = require 'server'

local function analyze_ast(filepath)
  local ast
  local ok, err = except.trycall(function()
    local parser = syntax.parser
    ast = parser:parse(fs.ereadfile(filepath), filepath)
    local context = AnalyzerContext(analyzer.visitors, parser, ast, 'c')
    analyzer.analyze(context)
  end)
  if not ok then
    console.debug(err)
  end
  return ast
end

local function analyze_and_find_loc(filepath, textpos)
  local content = fs.readfile(filepath)
  local pos = utils.linecol2pos(content, textpos.line, textpos.character)
  local ast = analyze_ast(filepath)
  if not ast then return end
  local nodes = utils.find_nodes_by_pos(ast, pos)
  local lastnode = nodes[#nodes]
  if not lastnode then return end
  local loc = {node=lastnode}
  if lastnode.attr._symbol then
    loc.symbol = lastnode.attr
  end
  for i=#nodes,1,-1 do -- find scope
    local attr = nodes[i].attr
    if attr.scope then
      loc.scope = attr.scope
      break
    end
  end
  return loc
end

local function markup_loc_info(loc)
  local ss = sstream()
  local attr = loc.node.attr
  local type = attr.type
  if type then
    if type.is_type then
      type = attr.value
      ss:add('**type** `', type.nickname or type.name, '`\n')
      local content = utils.get_node_src_content(type.node)
      ss:add('```nelua\n')
      if content then
        ss:add('', content,'\n')
      else
        ss:add('', type:typedesc(),'\n')
      end
      ss:add('```')
    end
  end
  return ss:tostring()
end

-- Get hover information
local function hover_method(reqid, params)
  local loc = analyze_and_find_loc(utils.uri2path(params.textDocument.uri), params.position)
  if loc then
    server.send_response(reqid, {contents = markup_loc_info(loc)})
  else
    server.send_response(reqid, {contents = ''})
  end
end

-- All capabilities supported by this language server.
server.capabilities ={
  hoverProvider= true,
}
server.methods = {
  ['textDocument/hover'] = hover_method,
}

-- Listen for requests.
server.listen(io.stdin, stdout)
