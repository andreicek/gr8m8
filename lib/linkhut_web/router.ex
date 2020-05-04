defmodule LinkhutWeb.Router do
  use LinkhutWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug LinkhutWeb.Plugs.AuthenticationPlug
    plug LinkhutWeb.Plugs.PrettifyPlug
  end

  pipeline :feed do
    plug :accepts, ["xml"]
  end

  pipeline :ensure_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LinkhutWeb do
    pipe_through :browser

    get "/", LinkController, :index
    get "/~:username", LinkController, :show

    get "/register", Auth.RegistrationController, :new
    post "/register", Auth.RegistrationController, :create

    get "/login", Auth.SessionController, :new
    post "/login", Auth.SessionController, :create
  end

  scope "/", LinkhutWeb do
    pipe_through [:browser, :ensure_auth]

    get "/profile", Settings.ProfileController, :show
    put "/profile", Settings.ProfileController, :update

    get "/add", LinkController, :new
    post "/add", LinkController, :insert

    get "/edit", LinkController, :edit
    put "/edit", LinkController, :update

    get "/delete", LinkController, :remove
    put "/delete", LinkController, :delete

    delete "/logout", Auth.SessionController, :delete
  end

  scope "/feed", LinkhutWeb, as: :feed do
    pipe_through :feed

    get "/~:username", FeedController, :feed
  end

  # Other scopes may use custom stacks.
  # scope "/api", LinkhutWeb do
  #   pipe_through :api
  # end
end