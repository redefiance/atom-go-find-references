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

    @loader.hide()

    @panel = new ResizablePanel
      item: this
      position: 'bottom'

    @pkgs = {}
    @pkgs[''] = @list
    @pkgs[''].files = {}

    # for testing
    # @open '/usr/lib/go/src/pkg/errors/errors.go', 300, '/usr/lib/go/src/pkg/'

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
    @loader.show()
    @list.focus()

    exit = (code)=>
      @loader.hide()
      @resize()

    stderr = (output)=>
      atom.notifications.addError output

    lines = []
    stdout = (output)=>
      for line in output.split '\n'
        lines.push line if line != ''
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

    command = atom.config.get 'go-find-references.path'
    args = ['-file', filepath, '-offset', offset, '-root', @root]
    process = new BufferedProcess({command, args, stdout, stderr, exit})

  showReference: ({pkg, file, line, column, text})->
    unless @pkgs[pkg]?
      entry = new TreeItem pkg, 'icon-file-directory'
      entry.files = {}
      @list.addItemu entry
      @pkgs[pkg] = entry

    unless @pkgs[pkg].files[file]?
      entry = new TreeItem file, 'icon-file-text'
      entry.lines = {}
      @pkgs[pkg].addItem entry
      @pkgs[pkg].files[file] = entry

    unless @pkgs[pkg].files[file].lines[line]?
      entry = new TreeItem line+': ' + text
      entry.onConfirm =>
        (atom.workspace.open @root+'/'+pkg+'/'+file,
          initialLine: line-1
          initialColumn: column-1
        ).done => @list.focus()
      @pkgs[pkg].files[file].addItem entry
      @pkgs[pkg].files[file].lines[line] = entry

    @resize()
