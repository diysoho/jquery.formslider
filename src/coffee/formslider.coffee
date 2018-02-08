#= include driver/**/*.coffee
#= include plugins/**/*.coffee
#= include lib/**/*.coffee

class @FormSlider
  @config = null # see below
  constructor: (@container, config) ->
    @logger           = new Logger('jquery.formslider')

    unless @container.length
      @logger.error('container is empty')
      return

    @setupConfig(config)
    @firstInteraction = false
    @events           = new EventManager(@logger)
    @locking          = new Locking(true)
    @setupDriver()
    @slides           = @driver.slides
    @loadPlugins()
    $(window).resize(@onResize)

  setupConfig: (config) =>
    FormSlider.config.plugins = [] if config?.plugins?
    @config = ObjectExtender.extend({}, FormSlider.config, config)

  setupDriver: =>
    DriverClass = window[@config.driver.class]
    @driver = new DriverClass(
      @container, @config.driver, @onBefore, @onAfter, @onReady
    )

  loadPlugins: =>
    @plugins = new PluginLoader(@, @config.pluginsGlobalConfig)
    @plugins.loadAll(
      @config.plugins
    )

  # called from @driver.next|prev|goto
  # return value(bool) indicates if transition allowed or not
  onBefore: (currentIndex, direction, nextIndex) =>
    return false if currentIndex == nextIndex
    return false if @locking.locked
    @locking.lock()

    current     = @slides.get(currentIndex)
    currentRole = $(current).data('role')
    next        = @driver.get(nextIndex)
    nextRole    = $(next).data('role')
    eventData   = [ current, direction, next ]

    # trigger leaving event, can also stop the transition
    event = @events.trigger("leaving.#{currentRole}.#{direction}", eventData...)
    if event.canceled
      @locking.unlock()
      return false

    # trigger before event
    @events.trigger("before.#{nextRole}.#{direction}", eventData...)

    @lastId          = @id()
    @lastCurrent     = current
    @lastNext        = next
    @lastCurrentRole = nextRole
    @lastDirection   = direction

  onAfter: =>
    # not an allowed after event
    return unless @locking.locked

                # current  , direction     , prev
    eventData = [ @lastNext, @lastDirection, @lastCurrent ]
    @events.trigger("after.#{@lastCurrentRole}.#{@lastDirection}", eventData...)

    unless @firstInteraction
      @firstInteraction = true
      @events.trigger('first-interaction', eventData...)

    @locking.unlock()

  onReady: =>
    @ready = true
    @events.trigger('ready')
    @locking.unlock()

  onResize: =>
    @events.trigger('resize')

  index: =>
    @driver.index()

  id: =>
    $(@driver.get()).data('id')

  next: =>
    return if @locking.locked

    possibleNextIndex = @index() + 1

    event = @events.trigger('before-driver-next')
    possibleNextIndex = event.nextIndex if event?.nextIndex

    @goto(possibleNextIndex)

  prev: =>
    @goto(@index() - 1) if @index() > 0

  goto: (indexFromZero) =>
    return if @locking.locked
    return if indexFromZero < 0 || indexFromZero > @slides.length - 1
    @driver.goto(indexFromZero)


@FormSlider.config =
  version: 1
  driver:
    class:    'DriverFlexslider'
    selector: '.formslider > .slide'

  pluginsGlobalConfig:
    answersSelector: '.answers'
    answerSelector:  '.answer'
    answerSelectedClass: 'selected'

  plugins: [
    { class: 'AddSlideClassesPlugin'          }
    { class: 'AnswerClickPlugin'              }
    { class: 'InputFocusPlugin'               }
    { class: 'BrowserHistoryPlugin'           }
    { class: 'JqueryValidatePlugin'           }
    { class: 'NormalizeInputAttributesPlugin' }
    { class: 'InputSyncPlugin'                }
    { class: 'NextOnKeyPlugin'                }
    { class: 'ArrowNavigationPlugin'          }
    { class: 'TabIndexSetterPlugin'           }
    { class: 'NextOnClickPlugin'              }
    { class: 'LoadingStatePlugin'             }
    { class: 'ProgressBarPlugin'              }
    { class: 'TrackUserInteractionPlugin'     }
    { class: 'LoaderSlidePlugin'              }
    { class: 'ContactSlidePlugin'             }
    { class: 'ConfirmationSlidePlugin'        }
    { class: 'EqualHeightPlugin'              }
    { class: 'ScrollUpPlugin'                 }
    { class: 'LazyLoadPlugin'                 }
  ]
