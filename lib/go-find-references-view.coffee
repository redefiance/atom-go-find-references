{BufferedProcess} = require 'atom'
{TreeView, TreeItem} = require 'atom-tree-view'
{ResizablePanel} = require 'atom-resizable-panel'
{$, View} = require 'space-pen'
fs = require 'fs'

class LineItem extends TreeItem
  initialize: (filepath, line, column, text)->
    super line, $("<span><b>#{line}:</b> #{text}</span>")
    open = (activate)->
      atom.workspace.open filepath,
        initialLine:   line-1
        initialColumn: column-1
        activatePane:  activate
    @onSelect  -> open false
    @onConfirm -> open true

module.exports =
class GoFindReferencesView extends View
  @content: -> @div =>
    @div outlet: 'loader', class: 'inline-block', =>
      @span class: 'loading loading-spinner-tiny inline-block'
      @span 'running go-find-references...'

  initialize: ->
    @loader.hide()
    @panel = new ResizablePanel
      item: this
      position: 'bottom'

    atom.commands.add 'atom-workspace', 'core:cancel', =>
      @clear()
    atom.commands.add 'atom-text-editor', 'go-find-references:toggle', =>
      @trigger()

    # for testing
    # testroot = '/usr/lib/go/src/pkg/'
    # testfile = '/usr/lib/go/src/pkg/errors/errors.go'
    # testoffset = 300
    # @open testfile, testoffset, testroot

  destroy: ->
    @panel.remove()
    @remove()

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
    @list?.remove()
    @resize()

  resize: ->
    h = @list?.height() or 0
    h += @loader.height() if @loader.isVisible()
    @panel.height Math.min h, 250

  open: (filepath, offset, root)->
    @clear()
    @append (@list = new TreeView)
    @list.focus()
    @loader.show()

    command = atom.config.get 'go-find-references.path'
    args = ['-file', filepath, '-offset', offset, '-root', root]

    lines = []
    stdout = (output)=>
      for line in output.split '\n'
        lines.push line if line != ''
      while lines.length >= 2
        [filepath, line, column] = lines.shift().split ':'
        text = lines.shift()

        path = filepath.substring(root.length).split '/'
        path.shift() if path[0] is ''
        path.push line

        @list.createItems path, (i, str)->
          item = switch i
            when path.length-1 then new LineItem filepath, line, column, text
            when path.length-2 then new TreeItem str, 'icon-file-text'
            else new TreeItem str, 'icon-file-directory'
          item.expand()
          item
    exit = (code)=>
      @panel.height @panel.height() - @loader.height()
      @loader.hide()
      @resize()
    stderr = (output)->
      atom.notifications.addError output
    new BufferedProcess({command, args, stdout, stderr, exit})
