module.exports =
  config:
    path:
      title: 'go-find-references path'
      description: 'Set this if the go-find-references executable is not found within your PATH'
      type: 'string'
      default: 'go-find-references'

  view: null

  activate: ->
    @view = new (require './go-find-references-view.coffee')

  deactivate: ->
    @view?.destroy()
    @view = null
