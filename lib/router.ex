defmodule Router do
  use Plug.Router
  use Plug.ErrorHandler
  import Rackla

  plug :match
  plug :dispatch

  # 1) Create a simple proxy.
  #
  # Use conn.query_string to retrieve a URL.
  # Call end-point with "/proxy?www.example.com".
  #
  # Functions: conn.query_string, request, response(conn)
  get "/proxy" do
    conn
  end

  # 2) Use the function concatenate_json to concatenate two API-calls.
  #
  # Functions: request, concatenate_json, response(conn)
  get "/concatenate-json" do
    url_1 = "http://ip.jsontest.com/"
    url_2 = "http://date.jsontest.com/"

    conn
  end

  # 3) Add a new header to the response: "foo" = "bar".
  #
  # Functions: Map.update!, Map.put
  get "/proxy/header" do
    header_adder = fn(response) ->
      response
    end

    "http://ip.jsontest.com/"
    |> request
    |> transform(header_adder)
    |> response(conn)
  end

  # 4) Use the function "transform" to modify the result and strip out everyting
  # except the date. Respond with just the date as a string, no JSON!
  #
  # Functions: request, transform(...), Map.update!, Map.get,
  # Poison.decode!, response(conn)
  get "/date" do
    url = "http://date.jsontest.com/"

    conn
  end

  # 5) Create an end-point which can receive an arbitrary amount of cities and
  # display the name and temperature (in Kelvin) as response in JSON format.
  #
  # If the URL is called with "/weather?Malmo,se|Lund,se|Helsingborg,se" it
  # should return [{"Lund":288.189},{"Helsingborg":286.139},{"Malmo":288.189}].
  # Use the API: http://api.openweathermap.org/data/2.5/weather?q=Malmo,se
  # Note that you have to make one call for each city!
  #
  # Hints:
  # Use concatenate_json(body_only: true)
  #
  # To create a new map with var1 and var2 as key/value, you can use
  # Map.put(%{}, var1, var2)
  #
  # Use String.split(conn.query_string, "|") to turn the string in to a list.
  get "/weather" do
    conn
  end

  # 6) Combine two APIs! Display the temperature as in the previous example, but
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
    conn
  end

  # 7) Astronomy picture of the dayS!
  #
  # Take an arbitrary amount of dates and use them to call the API:
  # https://api.data.gov/nasa/planetary/apod?concept_tags=True&api_key=DEMO_KEY&date=2015-03-29
  #
  # Use someting like this to encode the image data as a HTML image tag:
  # "<img src=\"data:image/jpeg;base64,#{Base.encode64(body)}\" height=\"150px\" width=\"150px\">"
  #
  # Stub code is provided to make the response valid HTML so you can view it in
  # your browser. There is no unit test for this, check it out yourself!
  get "/astronomy" do
    require Logger

    dates = String.split(conn.query_string, "|")

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

    # Create the pipeline here!

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