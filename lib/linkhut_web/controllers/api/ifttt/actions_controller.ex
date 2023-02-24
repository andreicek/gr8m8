defmodule LinkhutWeb.Api.IFTT.ActionsController do
  use LinkhutWeb, :controller

  plug :put_view, LinkhutWeb.Api.IFTT.ActionsView

  plug ExOauth2Provider.Plug.EnsureScopes, scopes: ~w(ifttt)

  alias Linkhut.Links
  alias LinkhutWeb.ErrorHelpers

  def add_public_link(conn, %{"actionFields" => params}) do
    user = conn.assigns[:current_user]

    case Links.create_link(user, params) do
      {:ok, link} ->
        conn
        |> render("success.json",
          id: link.url,
          url: Routes.user_bookmark_url(conn, :show, user.username, link.url)
        )

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> render("error.json",
          errors: Ecto.Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)
        )
    end
  end

  def add_public_link(conn, _params) do
    conn
    |> put_status(400)
    |> render("error.json", errors: ["missing parameters"])
  end

  def add_private_link(conn, %{"actionFields" => params}) do
    user = conn.assigns[:current_user]

    case Links.create_link(user, Map.put(params, "is_private", true)) do
      {:ok, link} ->
        conn
        |> render("success.json",
          id: link.url,
          url: Routes.user_bookmark_url(conn, :show, user.username, link.url)
        )

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> render("error.json",
          errors: Ecto.Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)
        )
    end
  end

  def add_private_link(conn, _params) do
    conn
    |> put_status(400)
    |> render("error.json", errors: ["missing parameters"])
  end

  defp save(conn, user, params) do
  end
end