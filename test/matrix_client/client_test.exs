defmodule Matrix2051.MatrixClient.ClientTest do
  use ExUnit.Case
  doctest Matrix2051.MatrixClient.Client

  import Mox
  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    config = start_supervised!({Matrix2051.Config, []})
    %{config: config}
  end

  test "initialization" do
    irc_mod = nil
    irc_pid = nil

    client =
      start_supervised!(
        {Matrix2051.MatrixClient.Client, {irc_mod, irc_pid, [httpoison: MockHTTPoison]}}
      )

    assert GenServer.call(client, {:dump_state}) ==
             {:initial_state,
              {
                irc_mod,
                irc_pid,
                [httpoison: MockHTTPoison]
              }}
  end

  test "connection without well-known" do
    MockHTTPoison
    |> expect(:get!, fn url ->
      assert url == "https://matrix.example.org/.well-known/matrix/client"

      %HTTPoison.Response{
        status_code: 404,
        body: """
          Error 404
        """
      }
    end)
    |> expect(:get!, fn url ->
      assert url == "https://matrix.example.org/_matrix/client/r0/login"

      %HTTPoison.Response{
        status_code: 200,
        body: """
          {
              "flows": [
                  {
                      "type": "m.login.password"
                  }
              ]
          }
        """
      }
    end)

    irc_mod = nil
    irc_pid = nil

    client =
      start_supervised!(
        {Matrix2051.MatrixClient.Client, {irc_mod, irc_pid, [httpoison: MockHTTPoison]}}
      )

    assert GenServer.call(client, {:connect, "user", "matrix.example.org", "p4ssw0rd"}) == {:ok}

    assert GenServer.call(client, {:dump_state}) ==
             {:connected,
              [
                irc_mod: irc_mod,
                irc_pid: irc_pid,
                raw_client: %Matrix2051.Matrix.RawClient{
                  base_url: "https://matrix.example.org",
                  httpoison: MockHTTPoison
                },
                local_name: "user",
                hostname: "matrix.example.org"
              ]}
  end

  test "connection with well-known" do
    MockHTTPoison
    |> expect(:get!, fn _url ->
      %HTTPoison.Response{
        status_code: 200,
        body: """
          {
            "m.homeserver": {
              "base_url": "https://matrix.example.com"
            }
          }
        """
      }
    end)
    |> expect(:get!, fn url ->
      assert url == "https://matrix.example.com/_matrix/client/r0/login"

      %HTTPoison.Response{
        status_code: 200,
        body: """
          {
              "flows": [
                  {
                      "type": "m.login.token"
                  },
                  {
                      "type": "m.login.password"
                  }
              ]
          }
        """
      }
    end)

    irc_mod = nil
    irc_pid = nil

    client =
      start_supervised!(
        {Matrix2051.MatrixClient.Client, {irc_mod, irc_pid, [httpoison: MockHTTPoison]}}
      )

    assert GenServer.call(client, {:connect, "user", "matrix.example.org", "p4ssw0rd"}) == {:ok}

    assert GenServer.call(client, {:dump_state}) ==
             {:connected,
              [
                irc_mod: irc_mod,
                irc_pid: irc_pid,
                raw_client: %Matrix2051.Matrix.RawClient{
                  base_url: "https://matrix.example.com",
                  httpoison: MockHTTPoison
                },
                local_name: "user",
                hostname: "matrix.example.org"
              ]}
  end

  test "connection without password flow" do
    MockHTTPoison
    |> expect(:get!, fn url ->
      assert url == "https://matrix.example.org/.well-known/matrix/client"

      %HTTPoison.Response{
        status_code: 404,
        body: """
          Error 404
        """
      }
    end)
    |> expect(:get!, fn url ->
      assert url == "https://matrix.example.org/_matrix/client/r0/login"

      %HTTPoison.Response{
        status_code: 200,
        body: """
          {
              "flows": [
                  {
                      "type": "m.login.token"
                  }
              ]
          }
        """
      }
    end)

    irc_mod = nil
    irc_pid = nil

    client =
      start_supervised!(
        {Matrix2051.MatrixClient.Client, {irc_mod, irc_pid, [httpoison: MockHTTPoison]}}
      )

    assert GenServer.call(client, {:connect, "user", "matrix.example.org", "p4ssw0rd"}) ==
             {:error, :no_password_flow}

    assert GenServer.call(client, {:dump_state}) ==
             {:initial_state,
              {
                irc_mod,
                irc_pid,
                [httpoison: MockHTTPoison]
              }}
  end
end
