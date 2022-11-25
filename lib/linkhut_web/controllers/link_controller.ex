defmodule LinkhutWeb.LinkController do
  use LinkhutWeb, :controller

  alias Linkhut.Accounts
  alias Linkhut.Links
  alias Linkhut.Links.Link
  alias Linkhut.Pagination
  alias Linkhut.Search
  alias Linkhut.Search.Context
  alias Linkhut.Tags

  @links_per_page 20
  @related_tags_limit 400

  def new(conn, params) do
    conn
    |> render("add.html",
      changeset: Links.change_link(%Link{}, Map.take(params, ["url", "title", "tags", "notes"]))
    )
  end

  def insert(conn, %{"link" => link_params}) do
    user = conn.assigns[:current_user]

    case Links.create_link(user, link_params) do
      {:ok, link} ->
        conn
        |> put_flash(:info, "Added link: #{link.url}")
        |> redirect(to: Routes.user_path(conn, :show, user.username))

      {:error, changeset} ->
        conn
        |> render("add.html", changeset: changeset)
    end
  end

  def edit(conn, %{"url" => url}) do
    user = conn.assigns[:current_user]
    link = Links.get(url, user.id)

    if link != nil do
      conn
      |> render("edit.html", changeset: Links.change_link(link))
    else
      conn
      |> put_flash(:error, "Couldn't find link for #{url}")
      |> redirect(to: Routes.link_path(conn, :show))
    end
  end

  def update(conn, %{"link" => %{"url" => url} = link_params}) do
    user = conn.assigns[:current_user]
    link = Links.get(url, user.id)

    case Links.update_link(link, link_params) do
      {:ok, link} ->
        conn
        |> put_flash(:info, "Saved link: #{link.url}")
        |> redirect(to: Routes.user_path(conn, :show, user.username))

      {:error, changeset} ->
        conn
        |> render("edit.html", changeset: changeset)
    end
  end

  def remove(conn, %{"url" => url}) do
    user = conn.assigns[:current_user]
    link = Links.get(url, user.id)

    if link != nil do
      conn
      |> render("delete.html", link: link, changeset: Links.change_link(link))
    else
      conn
      |> put_flash(:error, "Couldn't find link for #{url}")
      |> redirect(to: Routes.link_path(conn, :show))
    end
  end

  def delete(conn, %{"link" => %{"url" => url, "are_you_sure?" => confirmed}}) do
    user = conn.assigns[:current_user]
    link = Links.get(url, user.id)

    if confirmed == "true" do
      case Links.delete_link(link) do
        {:ok, link} ->
          conn
          |> put_flash(:info, "Deleted link: #{link.url}")
          |> redirect(to: Routes.user_path(conn, :show, user.username))

        {:error, changeset} ->
          conn
          |> render("delete.html", changeset: changeset)
      end
    else
      conn
      |> put_flash(:error, "Please confirm you want to delete this link")
      |> redirect(to: Routes.link_path(conn, :remove, url: url))
    end
  end

  defp has_query?(%{"query" => _}), do: true
  defp has_query?(_), do: false

  defp has_filters?(%{"username" => _}), do: true
  defp has_filters?(%{"tags" => _}), do: true
  defp has_filters?(_), do: false

  def show(conn, params) do
    cond do
      has_query?(params) -> query(conn, context(params), Map.get(params, "query"), page(params))
      has_filters?(params) -> filter(conn, context(params), page(params))
      true -> recent(conn, page(params))
    end
  end

  defp recent(conn, page) do
    context =
      case conn.assigns[:current_user] do
        nil -> %Context{}
        current_user -> %Context{visible_as: current_user.username}
      end

    links_query = Links.recent()

    conn
    |> render(:index,
      links: realize_query(links_query, page),
      tags: Tags.for_query(links_query, limit: @related_tags_limit),
      query: "",
      context: context,
      title: :recent
    )
  end

  defp query(conn, context, query, page) do
    context =
      case conn.assigns[:current_user] do
        nil -> context
        current_user -> %Context{context | visible_as: current_user.username}
      end

    links_query = Search.search(context, query)

    conn
    |> render(:index,
      links: realize_query(links_query, page),
      tags: Tags.for_query(links_query, limit: @related_tags_limit),
      query: query,
      context: context
    )
  end

  defp filter(conn, %Context{} = context, page) do
    context =
      case conn.assigns[:current_user] do
        nil -> context
        current_user -> %Context{context | visible_as: current_user.username}
      end

    links_query = Search.search(context, "")

    conn
    |> render(:index,
      links: realize_query(links_query, page),
      tags: Tags.for_query(links_query, limit: @related_tags_limit),
      query: "",
      context: context
    )
  end

  defp realize_query(query, page) do
    query
    |> Pagination.page(page, per_page: @links_per_page)
    |> Map.update!(
      :entries,
      &Enum.chunk_by(&1, fn link -> DateTime.to_date(link.inserted_at) end)
    )
  end

  defp context(%{"username" => username, "tags" => tags}) do
    %Context{from: Accounts.get_user!(username), tagged_with: Enum.uniq(tags)}
  end

  defp context(%{"tags" => tags}), do: %Context{tagged_with: Enum.uniq(tags)}
  defp context(%{"username" => username}), do: %Context{from: Accounts.get_user!(username)}
  defp context(_), do: %Context{}

  defp page(%{"p" => page}), do: page
  defp page(_), do: 1
end
