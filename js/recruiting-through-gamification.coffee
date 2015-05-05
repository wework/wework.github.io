---
# required for coffeescript to work
---

class Game
  constructor: () ->
    @ref = new Firebase('https://we-eng-blog.firebaseio.com')
    @redPill = $('#redPill')
    @levels = []
    @candidate = new Candidate(@ref.getAuth())
    return
  scrollTo: (level) ->
    $(window).scrollTo()
  init: ->
    $('#game .level').each (i, level) =>
      @levels.push new Level(level)

    @currentLevel = @levels.splice(0, 1)[0]

    @currentLevel.init(@candidate) if @candidate.initialized

    @redPill.on 'click', (e) =>
      return if @candidate.initialized
      @ref.authWithOAuthPopup "github", (error, authData) =>
        if error
          console.log("Login Failed!", error)
        else
          console.log("Authenticated successfully with payload:", authData)
          @ref.child("candidates/#{authData.uid}").set(authData)
          @candidate = new Candidate(authData)
          @currentLevel.init(@candidate)
      , {
        remember: "sessionOnly"
        scope: "user:email"
      }
    return

class Level
  constructor: (levelEl) ->
    @levelEl = $(levelEl)
    @levelEl.data('level', this)
    @continueButton = @levelEl.find('button.continue')
    @panda = new Panda(@levelEl)
  init: (candidate) ->
    @levelEl.show()
    $('html, body').animate({ scrollTop: @levelEl.offset().top }, 1000)

    @panda.init(candidate)
    @continueButton.on 'click', (e) =>
      nextLevelId = $(e.target).data('next-level')
      $(nextLevelId).data('level').init(game.candidate)

class Panda
  constructor: (containerEl) ->
    @containerEl = containerEl
    @chatSettings =
      startDelay: 300
      backSpeed: 0
      backDelay: 500
      typeSpeed: 0
      showCursor: false
      contentType: 'html'
      callback: => @containerEl.addClass('typed')
    return
  init: (candidate) ->
    pandaEl = @containerEl.find('panda')
    @chatSettings.strings = [pandaEl.html().replace('{name}', candidate.name())]

    pandaTpl = $.templates('#privatePandaTpl').render()
    pandaEl.replaceWith(pandaTpl)

    @element = @containerEl.find('.pirate-panda')
    @chatBox = @element.find('.chatbox')

    @chatBox.typed(@chatSettings)
    return

class Candidate
  constructor: (authData) ->
    @initialized = authData?
    @authData = authData
  avatarUrl: ->
    @authData.github.cachedUserProfile.avatar_url
  name: ->
    @authData.github.displayName.split(' ')[0]

$ ->
  window.game = new Game()
  game.init()

  # bluePill = $('#bluePill')
  # redPill = $('#redPill')
  # expCanvas = $('#expCanvas')
  # piratePanda = $('#piratePanda')
  # chatBox = piratePanda.find('.chatbox')
  # continueButton = piratePanda.find('.button.next')

  # chatSettings =
  #   startDelay: 300
  #   backSpeed: 0
  #   backDelay: 500
  #   typeSpeed: 0
  #   showCursor: false
  #   contentType: 'html'

  # redPill.on 'click', (e) ->
  #   e.preventDefault()

  #   $('html, body').css
  #     overflow: 'hidden'

  #   expCanvas.addClass('active')

  #   chatSettings.strings = [
  #     'Well done! You've made it to level 0.^300',
  #     'Don't worry, it'll get more interesting from here....'
  #   ]

  #   chatSettings.resetCallback = () -> chatBox.removeClass('done-typing')
  #   chatSettings.callback = () -> chatBox.addClass('done-typing')

  #   chatBox.typed(chatSettings)

  #   continueButton.on 'click', (e) ->
  #     chatBox.removeClass('done-typing')
  #     expCanvas.find('.inner-wrapper').css
  #       maxWidth: '90%'


  #     chatSettings.strings = [
  #       'Area you ready for level 1?'
  #     ]

  #     chatBox.typed(chatSettings)
