defmodule BitcoinSimulatorWeb.PageController do
  use BitcoinSimulatorWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html.eex")
  end
end
