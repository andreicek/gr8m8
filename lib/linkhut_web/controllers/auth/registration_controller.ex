defmodule LinkhutWeb.Auth.RegistrationController do
  use LinkhutWeb, :controller
  plug :put_view, LinkhutWeb.AuthView

  alias Linkhut.Accounts
  alias Linkhut.Accounts.User

  def new(conn, _params) do
    if conn.assigns[:current_user] != nil do
      conn
      |> redirect(to: Routes.profile_path(conn, :show))
    else
      conn
      |> render("register.html", changeset: Accounts.change_user(%User{}))
    end
  end

  def create(conn, %{"user" => %{"credential" => %{"invite" => "FIXME"}} = user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> put_flash(:info, "Welcome to linkhut!")
        |> redirect(to: Routes.link_path(conn, :show, []))

      {:error, changeset} ->
        conn
        |> put_flash(:info, "Wrong invite code.")
        |> render("register.html", changeset: changeset)
    end
  end

  def create(conn, _params) do
    conn
    |> redirect(to: Routes.link_path(conn, :show, []))
  end
end
