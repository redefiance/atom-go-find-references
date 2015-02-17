{BufferedProcess} = require 'atom'
{$, SelectListView, View} = require 'atom-space-pen-views'

module.exports =
class GoFindReferencesView extends SelectListView
  @activate: ->
    new GoFindReferencesView

  # @content: ->
  #   @div => @subview 'listView', new SelectListView

  initialize: ->
    super
    # @filterEditorView.hide()
    @panel = atom.workspace.addBottomPanel item: this, visible: false

    atom.commands.add 'atom-text-editor', 'go-find-references:toggle', => @toggle()

  viewForItem: (item)->
    "<li>
    <table><tr>
    <td style='padding-left: 10px' width='100%'>#{item.text}</td>
    <td style='padding-right: 10px'>#{item.file}:#{item.line}</td>
    </tr><table>
    </li>"

  getFilterKey: ->
    'file'

  toggle: ->
    if @panel.isVisible()
      @cancel()
    else
      @open()

  open: ->
    @items = []
    @findReferences()

    @panel.show()
    @storeFocusedElement()
    @focusFilterEditor()
    @focus()

  cancelled: ->
    @panel.hide()

  confirmed: (item)->
    atom.workspace.open item.file, initialLine: item.line-1
    @cancel()

  findReferences: ->
    buffer = atom.workspace.getActiveTextEditor()
    buffer.save() if buffer.isModified()

    wordStart = buffer.getSelectedBufferRange().start
    offset = buffer.getTextInBufferRange([[0,0], wordStart]).length
    filePath = buffer.getPath()
    root = atom.project.getPaths()[0]

    command = 'go-find-references'
    args = ['-file', filePath, '-offset', offset, '-root', root]
    stdout = (output)=>
      lines = output.split '\n'
      for i in [0..lines.length-1] by 2
        break if lines[i] == ""
        del = lines[i].lastIndexOf ':'
        @items.push
          file: lines[i].substring 0, del
          line: parseInt lines[i].substring del+1
          text: lines[i+1]
      @setItems @items

    stderr = (output)=>
      atom.notifications.addError output
    exit = (code)=>
      console.log code
    process = new BufferedProcess({command, args, stdout, stderr, exit})
