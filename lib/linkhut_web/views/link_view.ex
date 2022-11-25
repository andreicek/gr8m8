defmodule LinkhutWeb.LinkView do
  use LinkhutWeb, :view

  alias Atomex.{Entry, Feed}
  alias Linkhut.Search.Context
  alias LinkhutWeb.Router.Helpers, as: RouteHelpers

  @doc """
  Provides the path of the current context with the provided parameters

  ## Options

  Accepts one of the following options:
    * `:username` - reduce the context to the given username (resets page)
    * `:tag` - reduce the context to the given tag (resets page)
    * `:page` - provides results for the given page

  ## Examples

  Given a current path of `"/foo"`

      iex> current_path(conn, username: "bob")
      "/~bob/foo"
      iex> current_path(conn, page: 3)
      "/foo?p=3"
      iex> current_path(conn, tag: "bar")
      "/foo/bar"
  """
  @spec current_path(Plug.Conn.t(), Keyword.t()) :: String.t()
  def current_path(conn, opts)

  def current_path(%Plug.Conn{path_info: path, query_params: params} = conn, username: username) do
    current_path(%Plug.Conn{
      conn
      | path_info: Enum.uniq(["~" <> username | path]),
        query_params: Map.take(params, ["query"])
    })
  end

  def current_path(%Plug.Conn{path_info: path, query_params: params} = conn, tag: tag) do
    current_path(%Plug.Conn{
      conn
      | path_info: Enum.uniq(path ++ [tag]),
        query_params: Map.take(params, ["query"])
    })
  end

  def current_path(%Plug.Conn{query_params: params} = conn, page: page) do
    current_path(%Plug.Conn{conn | query_params: Map.put(Map.take(params, ["query"]), :p, page)})
  end

  defp current_path(%Plug.Conn{query_params: params} = conn) do
    case context(conn) do
      %{username: username, tags: tags} when is_binary(username) ->
        RouteHelpers.user_path(conn, :show, username, tags, params)

      %{username: username} when is_binary(username) ->
        RouteHelpers.user_path(conn, :show, username, params)

      %{tags: tags} ->
        RouteHelpers.tags_path(conn, :show, tags, params)

      _ ->
        RouteHelpers.link_path(conn, :show, params)
    end
  end

  @doc """
  Provides the path to the feed view of the current page
  """
  def feed_path(%Plug.Conn{} = conn) do
    context = context(conn)

    case context do
      %{username: username, tags: tags} when is_binary(username) ->
        RouteHelpers.feed_user_path(conn, :show, username, tags)

      %{username: username} when is_binary(username) ->
        RouteHelpers.feed_user_path(conn, :show, username)

      %{tags: tags} ->
        RouteHelpers.feed_tags_path(conn, :show, tags)

      _ ->
        RouteHelpers.feed_link_path(conn, :show)
    end
  end

  defp context(%Plug.Conn{path_info: path}) do
    case path do
      ["~" <> username] -> %{username: username}
      ["~" <> username | tags] -> %{username: username, tags: tags}
      [] -> %{}
      tags -> %{tags: tags}
    end
  end

  @doc """
  Renders a feed of links
  """
  def render("index.xml", %{
        conn: conn,
        context: %Context{from: user, tagged_with: []},
        links: links
      })
      when not is_nil(user) do
    title = LinkhutWeb.Gettext.gettext("Bookmarks for linkhut user: %{user}", user: user.username)
    feed_url = Routes.feed_user_url(conn, :show, user.username)
    html_url = Routes.user_url(conn, :show, user.username)

    render_feed(title, feed_url, html_url, links)
  end

  def render("index.xml", %{
        conn: conn,
        context: %Context{from: user, tagged_with: tags},
        links: links
      })
      when not is_nil(user) do
    title =
      LinkhutWeb.Gettext.gettext("Bookmarks for linkhut user: %{user} and tagged with: %{tags}",
        user: user.username,
        tags: Enum.join(tags, ",")
      )

    feed_url = Routes.feed_user_url(conn, :show, user.username, tags)
    html_url = Routes.user_url(conn, :show, user.username, tags)

    render_feed(title, feed_url, html_url, links)
  end

  def render("index.xml", %{conn: conn, context: %Context{tagged_with: []}, links: links}) do
    title = LinkhutWeb.Gettext.gettext("Recent bookmarks")
    feed_url = Routes.feed_link_url(conn, :show)
    html_url = Routes.link_url(conn, :show)

    render_feed(title, feed_url, html_url, links)
  end

  def render("index.xml", %{conn: conn, context: %Context{tagged_with: tags}, links: links})
      when not is_nil(tags) do
    title =
      LinkhutWeb.Gettext.gettext("Bookmarks tagged with: %{tags}", tags: Enum.join(tags, ","))

    feed_url = Routes.feed_tags_url(conn, :show, tags)
    html_url = Routes.tags_url(conn, :show, tags)

    render_feed(title, feed_url, html_url, links)
  end

  defp render_feed(title, feed_url, html_url, links) do
    Feed.new(
      feed_url,
      DateTime.utc_now(),
      title
    )
    |> Feed.link(feed_url, rel: "self", type: "application/atom+xml")
    |> Feed.link(html_url, rel: "alternate", type: "text/html")
    |> Feed.entries(
      links.entries
      |> Enum.flat_map(fn links -> links end)
      |> Enum.map(fn link -> feed_entry(link, html_url) end)
    )
    |> Feed.build()
    |> Atomex.generate_document()
  end

  defp feed_entry(link, html_url) do
    Entry.new(link.url, link.inserted_at, link.title)
    |> Entry.link(link.url, rel: "alternate")
    |> Entry.content(link.notes)
    |> Entry.author(link.user.username, uri: html_url)
    |> (fn entry ->
          Enum.reduce(link.tags, entry, fn tag, entry ->
            Entry.category(entry, tag, label: tag)
          end)
        end).()
    |> Entry.build()
  end
end
