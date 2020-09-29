defmodule LinkhutWeb.Settings.ExportController do
  use LinkhutWeb, :controller

  @moduledoc """
  Controller for exporting bookmarks
  """
  plug :put_view, LinkhutWeb.SettingsView

  alias Linkhut.Dump

  def show(conn, _) do
    render(conn, "export.html")
  end

  def download(conn, _) do
    user = conn.assigns[:current_user]
    links = Dump.export(user)

    bookmarks = render(conn, "bookmarks.netscape", links: links)
    send_download(conn, {:binary, bookmarks}, [filename: "bookmarks.html", content_type: "html"])
  end
end