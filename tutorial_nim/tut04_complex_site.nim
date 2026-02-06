import cherrynim, asyncdispatch, tables

type
  ExtraLinksPage = ref object of Controller
  LinksPage = ref object of Controller
    extra*: ExtraLinksPage
  JokePage = ref object of Controller
  HomePage = ref object of Controller
    joke*: JokePage
    links*: LinksPage

proc index*(h: HomePage): Future[string] {.async, gcsafe.} =
  return "Home page. <a href=\"/joke/\">Joke</a>"

proc index*(j: JokePage): Future[string] {.async, gcsafe.} =
  return "Perl file joke."

proc index*(l: LinksPage): Future[string] {.async, gcsafe.} =
  return "Links page."

proc index*(e: ExtraLinksPage): Future[string] {.async, gcsafe.} =
  return "Extra links."

proc main() =
  let extra = ExtraLinksPage()
  extra.handlers = initTable[string, Handler]()
  extra.exposeHandlers("index")

  let links = LinksPage(extra: extra)
  links.handlers = initTable[string, Handler]()
  links.exposeHandlers("index")

  let joke = JokePage()
  joke.handlers = initTable[string, Handler]()
  joke.exposeHandlers("index")

  let root = HomePage(joke: joke, links: links)
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index")

  quickstart(root)

if isMainModule: main()
