defmodule LinkhutWeb.Plugs.EnsureAuth do
  @behaviour Plug

  @moduledoc """
  Plug ensuring the requester is logged in.
  """

  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]
  import Plug.Conn
  alias Linkhut.Accounts
  alias LinkhutWeb.Router.Helpers, as: RouteHelpers

  @doc false
  @impl true
  def init([]), do: false

  @doc false
  @impl true
  def call(conn, _) do
    if user = get_user(conn) do
      assign(conn, :current_user, user)
    else
      auth_error!(conn)
    end
  end

  defp get_user(conn) do
    case conn.assigns[:current_user] do
      nil ->
        fetch_user(conn)

      user ->
        user
    end
  end

  defp fetch_user(conn) do
    if user_id = get_session(conn, :user_id) do
      Linkhut.Accounts.get_user!(user_id)
    else
      nil
    end
  end

  defp auth_error!(conn) do
    conn
    |> store_path_in_session()
    |> put_flash(:error, "Login required")
    |> redirect(to: RouteHelpers.session_path(conn, :new))
    |> halt()
  end

  defp store_path_in_session(conn) do
    # Get HTTP method and url from conn
    method = conn.method
    path = conn.request_path

    # If conditions apply store path in session, else return conn unmodified
    case {method, String.match?(path, ~r/^\/(add)$/)} do
      {"GET", true} ->
        put_session(conn, :login_redirect_path, path)

      {_, _} ->
        conn
    end
  end
end