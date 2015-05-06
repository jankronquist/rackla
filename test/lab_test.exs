defmodule RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts Router.init([])

  test "1) Create a simple proxy" do
    conn =
      conn(:get, "/proxy/?http://validate.jsontest.com/?json={%22key%22:%22value%22}")
      |> Router.call(@opts)

    assert conn.state == :chunked
    assert conn.status == 200
    assert conn.port == 80
    assert conn.scheme == :http
    assert conn.method == "GET"
    assert get_resp_header(conn, "Content-Type") == ["application/json; charset=ISO-8859-1"]

    json_response = Poison.decode!(conn.resp_body)
    assert json_response["empty"] == false
    assert json_response["object_or_array"] == "object"
    assert json_response["size"] == 1
    assert json_response["validate"] == true
  end

  test "2) Concatenate json APIs" do
    conn =
      conn(:get, "/concatenate-json")
      |> Router.call(@opts)

    assert conn.state == :chunked
    assert conn.status == 200
    assert conn.port == 80
    assert conn.scheme == :http
    assert conn.method == "GET"
    assert get_resp_header(conn, "Content-Type") == ["application/json"]

    json_response = Poison.decode!(conn.resp_body)

    assert length(json_response) == 2
    [response_1, response_2] = json_response
    response_body_1 = Map.get(response_1, "body")
    response_body_2 = Map.get(response_2, "body")

    assert Map.has_key?(response_body_1, "ip") && Map.has_key?(response_body_2, "date") || Map.has_key?(response_body_2, "ip") && Map.has_key?(response_body_1, "date")
  end

  test "3) Add new header to response (foo: bar)" do
    conn =
      conn(:get, "/proxy/header")
      |> Router.call(@opts)

    assert conn.state == :chunked
    assert conn.status == 200
    assert conn.port == 80
    assert conn.scheme == :http
    assert conn.method == "GET"

    assert get_resp_header(conn, "foo") == ["bar"]
  end

  test "4) Create a date API" do
    conn =
      conn(:get, "/date")
      |> Router.call(@opts)

    assert conn.state == :chunked
    assert conn.status == 200
    assert conn.port == 80
    assert conn.scheme == :http
    assert conn.method == "GET"

    {{year, month, day}, _other} = :calendar.local_time
    date_string = "#{String.slice("0#{month}", -2, 2)}-#{String.slice("0#{day}", -2, 2)}-#{year}"

    assert conn.resp_body == date_string
  end

  test "5) Create a weather end-point" do
    conn =
      conn(:get, "/weather?halmstad,se|san francisco,us|stockholm,se")
      |> Router.call(@opts)

    assert conn.state == :chunked
    assert conn.status == 200
    assert conn.port == 80
    assert conn.scheme == :http
    assert conn.method == "GET"

    response = Poison.decode!(conn.resp_body)

    length(response) == 3
    [halmstad, sanfran, stockholm]  = response
    
    assert Map.keys(halmstad) == ["Halmstad"]
    assert Map.keys(sanfran) == ["San Francisco"]
    assert Map.keys(stockholm) == ["Stockholm"]
  end


  test "6) Combine two APIs" do
    conn =
      conn(:get, "/weather/postal_code?22644|55454")
      |> Router.call(@opts)

    assert conn.state == :chunked
    assert conn.status == 200
    assert conn.port == 80
    assert conn.scheme == :http
    assert conn.method == "GET"

    response = Poison.decode!(conn.resp_body)
    
    assert length(response) == 2
    
    [lund, jkpg] = response
    assert lund |> Map.keys |> Enum.at(0) |> String.contains?("Lund")
    assert jkpg |> Map.keys |> Enum.at(0) |> String.contains?("Jonkoping")
  end
end