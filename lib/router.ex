defmodule Router do
  use Plug.Router
  use Plug.ErrorHandler
  import Rackla

  plug :match
  plug :dispatch

  # 1) Create a simple proxy.
  #
  # Use conn.query_string to retrieve a url.
  # Call end-point with "/proxy?www.example.com".
  #
  # Functions: conn.query_string, request, response(conn)
  get "/proxy" do
    conn.query_string
    |> request
    |> response(conn)
  end

  # 2) Use the function concatenate_json to concatenate two API-calls.
  #
  # Functions: request, concatenate_json, response(conn)
  get "/concatenate-json" do
    url_1 = "http://ip.jsontest.com/"
    url_2 = "http://date.jsontest.com/"

    [url_1, url_2]
    |> request
    |> concatenate_json
    |> response(conn)
  end

  # 3) Add a new header to the response: "foo" = "bar".
  #
  # Functions: request, transform(header), Map.update!, Map.put, response(conn)
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

  # 4) Use the function "transform" to modify the result and strip out everyting
  # except the date. Respond with just the date as a string, no JSON!
  #
  # Functions: request, transform(datifyer), Map.update!, Map.get,
  # Poison.decode!, response(conn)
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

  # 5) Create an end-point which can receive an arbitrary amount of cities and
  # display the name and temperature (in Kelvin) as response.
  #
  # If the URL is called with "/weather?Malmo,se|Lund,se|Helsingborg,se" it
  # should return [{"Lund":288.189},{"Helsingborg":286.139},{"Malmo":288.189}]
  # in JSON format. Hint: use concatenate_json(body_only: true)
  #
  # Use the API http://api.openweathermap.org/data/2.5/weather?q=Malmo,se
  # Note that you have to make one call for each city!
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

  # 6) Combine two APIs! Display the weather as in the previous example, but
  # instead we will accept an arbitrary amount of postal codes.
  #
  # If the URL is called with "/weather/postal_code?22644|21120" it should
  # return [{"Lunds Kommun":286.753},{"Malmoe":286.753}] in JSON format.
  #
  # First call the API http://yourmoneyisnowmymoney.com/api/zipcodes/?zipcode=<postal code>
  # and extract the latitude and longitude.
  #
  # Then call the API http://api.openweathermap.org/data/2.5/weather?lat=<latitude>&lon=<longitude>
  # to get the weather data.
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

  # 7) Astronomy picture of the dayS!
  #
  # Take an arbitrary amount of dates and use them to call the API:
  # https://api.data.gov/nasa/planetary/apod?concept_tags=True&api_key=DEMO_KEY&date=2015-03-29
  #
  # Use someting like this to encode the image data as text:
  # "<img src=\"data:image/jpeg;base64,#{Base.encode64(body)}\" height=\"150px\" width=\"150px\">"
  #
  # Stub code is provided to make it valid HTML so you can view it in your
  # browser. There is no unit test for this, check it out yourself!
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