import cherrynim, asyncdispatch, tables

type
  ExtraLinksPage = ref object of Controller
  LinksPage = ref object of Controller
    extra*: ExtraLinksPage
  JokePage = ref object of Controller
  HomePage = ref object of Controller
    joke*: JokePage
    links*: LinksPage

method index*(h: HomePage): Future[string] {.async, base, gcsafe.} =
  return "Home page. <a href=\"/joke/\">Joke</a>"

method index*(j: JokePage): Future[string] {.async, base, gcsafe.} =
  return "Perl file joke."

method index*(l: LinksPage): Future[string] {.async, base, gcsafe.} =
  return "Links page."

method index*(e: ExtraLinksPage): Future[string] {.async, base, gcsafe.} =
  return "Extra links."

proc main() =
  let extra = ExtraLinksPage()
  extra.handlers = initTable[string, Handler]()
  extra.exposeHandlers("index")

  let links = LinksPage(extra: extra)
  links.handlers = initTable[string, Handler]()
  links.exposeHandlers("index")
  # Manual sub-registration
  links.handlers["extra"] = proc(p: Table[string, string]): Future[string] {.async, gcsafe.} =
    return await dispatch(links.extra, @[], p)

  let joke = JokePage()
  joke.handlers = initTable[string, Handler]()
  joke.exposeHandlers("index")

  let root = HomePage(joke: joke, links: links)
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index")
  root.handlers["joke"] = proc(p: Table[string, string]): Future[string] {.async, gcsafe.} =
    return await dispatch(root.joke, @[], p)
  root.handlers["links"] = proc(p: Table[string, string]): Future[string] {.async, gcsafe.} =
    return await dispatch(root.links, @[], p)

  quickstart(root)

if isMainModule: main()
