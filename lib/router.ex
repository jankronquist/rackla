defmodule Router do
  use Plug.Router
  use Plug.ErrorHandler
  import Rackla

  plug :match
  plug :dispatch

  get "/proxy" do
    conn.query_string
    |> request
    |> response(conn)
  end

  get "/concatenate-json" do
    url_1 = "http://ip.jsontest.com/"
    url_2 = "http://date.jsontest.com/"

    [url_1, url_2]
    |> request
    |> concatenate_json
    |> response(conn)
  end

  get "/proxy/header" do
    header = fn(response) ->
      Map.update!(response, :headers, fn(head) ->
        Map.put(head, "foo", "bar")
      end)
    end

    "http://ip.jsontest.com/"
    |> request
    |> transform(header)
    |> response(conn)
  end

  get "/date" do
    datifyer = fn(response) ->
      Map.update!(response, :body, fn(body) ->
        body
        |> Poison.decode!
        |> Map.get("date")
      end)
    end

    "http://date.jsontest.com/"
    |> request
    |> transform(datifyer)
    |> response(conn)
  end

  get "/weather" do
    temperature_extractor = fn(item) ->
      Map.update!(item, :body, fn(body) ->
        response_body = Poison.decode!(body)

        Map.put(%{}, response_body["name"], response_body["main"]["temp"])
        |> Poison.encode!
      end)
    end

    conn.query_string
    |> String.split("|")
    |> Enum.map(&("http://api.openweathermap.org/data/2.5/weather?q=#{&1}"))
    |> request
    |> transform(temperature_extractor)
    |> concatenate_json(body_only: true)
    |> response(conn)
  end

  get "/weather/postal_code" do
    postal_code_to_temperature = fn(item) ->
      Map.update!(item, :body, fn(body) ->

        %{"lat" => lat, "lng" => lng} =
          Poison.decode!(body)
          |> Map.get("results")
          |> Enum.at(0)

        response_body =
          "http://api.openweathermap.org/data/2.5/weather?lat=#{lat}&lon=#{lng}"
          |> request
          |> collect_response
          |> Enum.at(0)
          |> Map.get(:body)
          |> Poison.decode!

        Map.put(%{}, response_body["name"], response_body["main"]["temp"])
        |> Poison.encode!
      end)
    end

    conn.query_string
    |> String.split("|")
    |> Enum.map(&("http://yourmoneyisnowmymoney.com/api/zipcodes/?zipcode=#{&1}"))
    |> request
    |> transform(postal_code_to_temperature)
    |> concatenate_json(body_only: true)
    |> response(conn)
  end

  get "/astronomy" do
    require Logger

    dates = conn.query_string

    binary_to_img = fn(item) ->
      Map.update!(item, :body, fn(body) ->
        "<img src=\"data:image/jpeg;base64,#{Base.encode64(body)}\" height=\"150px\" width=\"150px\">"
      end)
    end

    chunk_status =
      conn
      |> send_chunked(200)
      |> chunk("<!doctype html><html lang=\"en\"><head></head><body>")

    conn =
      case chunk_status do
        {:ok, new_conn} ->
          new_conn

        {:error, reason} ->
          Logger.error("Unable to chunk response: #{reason}")
          conn
      end

    conn =
      dates
      |> String.split("|")
      |> Enum.map(&("https://api.data.gov/nasa/planetary/apod?concept_tags=True&api_key=DEMO_KEY&date=#{&1}"))
      |> request
      |> collect_response
      |> Enum.map(fn(response) -> response.body |> Poison.decode! |>  Map.get("url") end)
      |> request
      |> transform(binary_to_img)
      |> response(conn)

    case chunk(conn, "</body></html>") do
      {:ok, new_conn} -> new_conn

      {:error, reason} ->
        Logger.error("Unable to chunk response: #{reason}")
        conn
    end
  end

  match _ do
   send_resp(conn, 404, "end-point not found")
  end
end