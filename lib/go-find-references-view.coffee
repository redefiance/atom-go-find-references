{BufferedProcess} = require 'atom'
{TreeView, TreeItem} = require 'atom-tree-view'
{ResizablePanel} = require 'atom-resizable-panel'
{View} = require 'space-pen'
fs = require 'fs'

module.exports =
class GoFindReferencesView extends View
  @content: -> @div =>
    @div outlet: 'loader', class: 'inline-block', =>
      @span class: 'loading loading-spinner-tiny inline-block'
      @span 'running go-find-references...'
    @subview 'list', new TreeView

  initialize: ->
    atom.commands.add 'atom-workspace', 'core:cancel', => @clear()
    atom.commands.add 'atom-text-editor', 'go-find-references:toggle', => @trigger()

    @panel = new ResizablePanel
      item: this
      position: 'bottom'

    @pkgs = {}
    @pkgs[''] = @list
    @pkgs[''].files = {}

  trigger: ->
    buffer = atom.workspace.getActiveTextEditor()
    buffer.save() if buffer.isModified()

    filepath = buffer.getPath()
    wordstart = buffer.getSelectedBufferRange().start
    offset = buffer.getTextInBufferRange([[0,0], wordstart]).length
    root = fs.realpathSync atom.project.getPaths()[0]
    root += '/' unless root.endsWith '/'

    if '.go' == filepath.substring filepath.length - 3
      @clear()
      @open filepath, offset, root

  clear: ->
    for pkg of @pkgs
      for file of @pkgs[pkg].files
        for line of @pkgs[pkg].files[file].lines
          @pkgs[pkg].files[file].lines[line].destroy()
        @pkgs[pkg].files[file].destroy()
      @pkgs[pkg].destroy?()

    @pkgs = {}
    @pkgs[''] = @list
    @pkgs[''].files = {}
    @resize()

  resize: ->
    h = @list.height()
    h += @loader.height() if @loader.isVisible()
    @panel.height Math.min h, 250

  open: (filepath, offset, @root)->
    # @refname = undefined

    exit = (code)=>
      @loader.hide()
      @resize()

    stderr = (output)=>
      atom.notifications.addError output

    lines = []
    stdout = (output)=>
      for line in output.split '\n'
        lines.push line if line != ''
      # if not @refname? and lines.length >= 1
      #   @refname = lines[0]
      #   lines.shift()
      while lines.length >= 2
        line = lines.shift()
        split = line.split ':'
        filename = split[0].substring @root.length
        cut = filename.lastIndexOf '/'
        @showReference
          pkg: filename.substring(0, cut)
          file: filename.substring(cut+1)
          line: split[1]
          column: split[2]
          text: lines.shift()

    command = 'go-find-references'
    args = ['-file', filepath, '-offset', offset, '-root', @root]
    console.log args
    process = new BufferedProcess({command, args, stdout, stderr, exit})

    @loader.show()

  showReference: ({pkg, file, line, column, text})->
    unless @pkgs[pkg]?
      item = new TreeItem pkg, 'icon-file-directory'
      item.files = {}
      @list.addItem item
      @pkgs[pkg] = item

    unless @pkgs[pkg].files[file]?
      item = new TreeItem file, 'icon-file-text'
      item.lines = {}
      @pkgs[pkg].addItem item
      @pkgs[pkg].files[file] = item

    unless @pkgs[pkg].files[file].lines[line]?
      item = new TreeItem line+': ' + text
      item.confirm = =>
        atom.workspace.open @root+'/'+pkg+'/'+file,
          initialLine: line-1
          initialColumn: column-1
      @pkgs[pkg].files[file].addItem item
      @pkgs[pkg].files[file].lines[line] = item


    unless @list.find('.selected')[0]
      @list.selectEntry @list.find('.entry').first()[0]
      @list.focus()
    @resize()
