defmodule LiveViewDemoWeb.PieChartLive do
  @moduledoc """
  SVG Pie Chart Maker
  """

  use Phoenix.LiveView
  alias __MODULE__

  defstruct name: "",
            value: 0,
            percent: 0,
            color: "",
            angle: 0,
            slice_shape: "",
            rotation: 0

  def render(assigns) do
    LiveViewDemoWeb.PageView.render("piechart.html", assigns)
  end

  def render_piechart(assigns) do
    ~L"""
    <svg viewBox="0 0 700 500" xmlns="http://www.w3.org/2000/svg"
    xmlns:xlink="http://www.w3.org/1999/xlink">

    <!-- render patterns for use in CSS -->

    <%= LiveViewDemoWeb.PieChartLive.render_patterns(%{}) %>

    <!-- pie chart's main template -->

    <g transform="translate(350, 250) scale(<%= @scale %>) ">

    <!-- generate pie slices -->

      <%= for slice <- @piechart do %>
        <path id="slice-<%= slice.name %>" d="<%= slice.slice_shape %>"
        transform="rotate(<%= slice.rotation %> 0 0)"
        class="<%= slice.color %>
        <%= if @piechart_style == "pie", do: "pieslice_pie", else: "pieslice" %>
        <%= if @piechart_style == "pie", do: slice.name, else: "" %>" />
      <% end %>

      <%= if @piechart_style == "pie" do %>
        <circle cx="0" cy="0" r="<%= @radius %>" stroke="#d07e3e" stroke-width="10" fill="none" />
      <% end %>
    </g>
    </svg>
    """
  end

  def render_patterns(assigns) do
    LiveViewDemoWeb.PageView.render("piechart_patterns.html", assigns)
  end

  @items ~w(kiwi blueberry banana strawberry mint apple chocolate)

  def mount(_session, socket) do
    pie_input = random_input(@items)

    data = %{
      piechart: %{},
      pie_input: pie_input,
      radius: 100,
      scale: 2,
      piechart_style: "basic",
      colors: colors("basic")
    }

    piechart = generate_piechart(pie_input, data)
    {:ok, assign(socket, data: %{data | piechart: piechart})}
  end

  defp generate_piechart(pie_input, data) do
    normalized = normalize_input(pie_input)

    if Enum.empty?(normalized) do
      data.piechart
    else
      normalized
      |> Enum.map(fn {name, value} -> %PieChartLive{name: name, value: value} end)
      |> calculate_percents()
      |> calculate_angles()
      |> calculate_rotations()
      |> update_slices(data.radius)
      |> update_colors(data.colors)
    end
  end

  def handle_event("piechart", %{"pie_input" => pie_input}, socket) do
    data = socket.assigns.data
    piechart = generate_piechart(pie_input, data)
    {:noreply, assign(socket, data: %{data | piechart: piechart, pie_input: pie_input})}
  end

  def handle_event("ignore", _, socket) do
    {:noreply, socket}
  end

  def handle_event("piechart_style", %{"piechart_style" => style}, socket) do
    data = socket.assigns.data
    colors = colors(style)

    data = %{
      data
      | piechart_style: style,
        colors: colors,
        piechart: update_colors(data.piechart, colors)
    }

    {:noreply, assign(socket, data: data)}
  end

  defp update_slices(piechart, radius) do
    Enum.map(piechart, fn slice -> %{slice | slice_shape: slice_shape(slice, radius)} end)
  end

  defp update_colors(piechart, colors) do
    piechart
    |> Enum.zip(Enum.take(Stream.cycle(colors), length(piechart)))
    |> Enum.map(fn {slice, color} -> %{slice | color: color} end)
  end

  defp slice_shape(item, radius) do
    arc_style = if item.angle > 180, do: "1 1", else: "0 1"

    "m 0 0 l #{arc_start(radius)} a #{radius} #{radius} 0 #{arc_style} #{
      arc_end(item.angle, radius)
    } Z"
  end

  @start_angle 0
  defp arc_start(radius) do
    x = radius * :math.cos(@start_angle)
    y = radius * :math.sin(@start_angle)
    "#{x},#{y}"
  end

  defp arc_end(angle, radius) do
    x_prev = radius * :math.cos(@start_angle)
    y_prev = radius * :math.sin(@start_angle)
    angle = angle * (:math.pi() / 180)
    x = radius * :math.cos(angle)
    y = radius * :math.sin(angle)
    "#{x - x_prev},#{y - y_prev}"
  end

  defp calculate_percents(piechart) do
    total_sum = Enum.map(piechart, fn %{value: value} -> value end) |> Enum.sum()
    one_percent = total_sum / 100
    Enum.map(piechart, fn %{value: value} = slice -> %{slice | percent: value / one_percent} end)
  end

  @full_circle 360
  defp calculate_angles(piechart) do
    Enum.map(piechart, fn %{percent: percent} = slice ->
      %{slice | angle: percent / 100 * @full_circle}
    end)
  end

  defp calculate_rotations(piechart) do
    rotations =
      piechart
      |> Enum.map(fn %{angle: angle} -> angle end)
      |> Enum.reverse()
      |> tl()
      |> Enum.reverse()

    rotations = Enum.scan([0 | rotations], &(&1 + &2))

    piechart
    |> Enum.zip(rotations)
    |> Enum.map(fn {slice, rotation} -> %{slice | rotation: rotation} end)
  end

  def random_input(items, count \\ 3) do
    items
    |> Enum.shuffle()
    |> Enum.take(count)
    |> Enum.zip(Enum.shuffle(1..100))
    |> Enum.map(fn {item, value} -> "#{item}: #{value}" end)
    |> Enum.join(", ")
  end

  def normalize_input(pie_input) do
    pie_input
    |> String.split(",", trim: true)
    |> Enum.map(&parse_data/1)
    |> Enum.reject(&(&1 == :error))
  end

  defp parse_data(data) do
    with [item, amount] <- String.split(data, ":", trim: true),
         {num, _} <- Integer.parse(String.trim(amount)) do
      {String.trim(item), num}
    else
      _ -> :error
    end
  end

  @basic 1..36 |> Enum.map(&"color#{&1}")

  def colors(style) do
    if style == "funky" do
      1..13
      |> Enum.map(&"funky#{&1}")
      |> Enum.shuffle()
    else
      @basic
    end
  end
end
