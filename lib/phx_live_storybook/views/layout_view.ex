defmodule PhxLiveStorybook.LayoutView do
  @moduledoc false
  use PhxLiveStorybook.Web, :view

  alias Makeup.Styles.HTML.StyleMap
  alias Phoenix.LiveView.JS
  alias PhxLiveStorybook.AssetHelpers
  alias PhxLiveStorybook.{ComponentEntry, FolderEntry, PageEntry}

  @env Application.compile_env(:phx_live_storybook, :env)

  defp makeup_stylesheet(conn) do
    style = storybook_setting(conn, :makeup_style, :monokai_style)
    apply(StyleMap, style, []) |> Makeup.stylesheet()
  end

  defp live_socket_path(conn = %Plug.Conn{}) do
    [Enum.map(conn.script_name, &["/" | &1]) | conn.private.live_socket_path]
  end

  defp storybook_css_path(conn), do: storybook_setting(conn, :css_path)
  defp storybook_js_path(conn), do: storybook_setting(conn, :js_path)

  defp title(socket) do
    storybook_setting(socket, :storybook_title, "Live Storybook")
  end

  defp storybook_setting(conn_or_socket, key, default \\ nil)

  defp storybook_setting(conn_or_socket, key, default) do
    otp_app = otp_app(conn_or_socket)
    backend_module = backend_module(conn_or_socket)
    Application.get_env(otp_app, backend_module, []) |> Keyword.get(key, default)
  end

  defp render_breadcrumb(socket, entry) do
    breadcrumb(socket, entry)
    |> Enum.intersperse(:separator)
    |> Enum.map_join("", fn
      :separator -> ~s|<i class="fat fa-angle-right lsb-px-2 lsb-text-slate-500"></i>|
      entry_name -> ~s|<span>#{entry_name}</span>|
    end)
    |> raw()
  end

  defp otp_app(s = %Phoenix.LiveView.Socket{}), do: s.assigns.__assigns__.otp_app
  defp otp_app(conn = %Plug.Conn{}), do: conn.private.otp_app

  defp backend_module(s = %Phoenix.LiveView.Socket{}), do: s.assigns.__assigns__.backend_module
  defp backend_module(conn = %Plug.Conn{}), do: conn.private.backend_module

  defp application_static_path(conn, path) do
    routes(conn).static_path(conn, path)
  end

  defp asset_path(conn_or_socket, path) do
    live_storybook_path(conn_or_socket, :root) <> "/assets/" <> asset_file_name(path, @env)
  end

  @manifest_path Path.expand("static/cache_manifest.json", :code.priv_dir(:phx_live_storybook))
  @external_resource @manifest_path
  @manifest AssetHelpers.parse_manifest(@manifest_path, @env)
  defp asset_file_name(asset, :prod) do
    if String.ends_with?(asset, [".js", ".css"]) do
      @manifest |> AssetHelpers.asset_file_name(asset, :prod)
    else
      asset
    end
  end

  defp asset_file_name(path, _env), do: path

  defp breadcrumb(socket, entry) do
    backend_module = backend_module(socket)

    {_, breadcrumb} =
      for path_item <- String.split(entry.storybook_path, "/", trim: true), reduce: {"", []} do
        {path, breadcrumb} ->
          path = path <> "/" <> path_item

          case backend_module.find_entry_by_path(path) do
            %FolderEntry{nice_name: nice_name} -> {path, [nice_name | breadcrumb]}
            %ComponentEntry{name: name} -> {path, [name | breadcrumb]}
            %PageEntry{name: name} -> {path, [name | breadcrumb]}
          end
      end

    Enum.reverse(breadcrumb)
  end
end
