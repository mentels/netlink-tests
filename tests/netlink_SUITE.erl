-module(netlink_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(VETH_END_A, "veth100").
-define(VETH_END_B, "veth200").

all() ->
    [should_notify_about_veth_interfaces_flags].

init_per_suite(Config) ->
    {ok, Addrs} = inet:getifaddrs(),
    case {lists:keyfind("veth100", 1, Addrs),
          lists:keyfind("veth200", 1, Addrs)} of
        {false, false} ->
            Cmd = io_lib:format("ip link add ~s type veth peer name ~s",
                                [?VETH_END_A, ?VETH_END_B]),
            os:cmd(Cmd);
        _ ->
            ct:fail("Interfaces ~p ~p already exist",
                    [?VETH_END_A, ?VETH_END_B])
    end,
    netlink:start(),
    Config.

end_per_suite(_Config) ->
    netlink:stop(),
    Cmd = io_lib:format("ip link del ~s", [?VETH_END_A]),
    os:cmd(Cmd).

should_notify_about_veth_interfaces_flags(_Config) ->
    %% GIVEN
    interface_down(?VETH_END_A),
    {ok, Ref} = netlink:subscribe(?VETH_END_A, [flags]),
    
    %% WHEN
    interface_up(?VETH_END_A),
    interface_down(?VETH_END_A),
    
    %% THEN
    receive
        {netlink, Ref, ?VETH_END_A, flags, OldFlags0, NewFlags0} ->
            ?assertMatch(undefined, OldFlags0),
            ?assert(lists:member(up, NewFlags0))
    after
        500 ->
            ct:fail("No notification about ~p ~n", [?VETH_END_A])
    end,
    receive
        {netlink, Ref, ?VETH_END_A, flags, OldFlags1, NewFlags1} ->
            ?assert(lists:member(up, OldFlags1)),
            ?assertNot(lists:member(up, NewFlags1))
    after
        500 ->
            ct:fail("No notification about", [?VETH_END_A])
    end.


interface_down(Intf) ->
    Cmd = io_lib:format("ip link set dev ~s down", [Intf]),
    os:cmd(Cmd).

interface_up(Intf) ->
    Cmd = io_lib:format("ip link set dev ~s up", [Intf]),
    os:cmd(Cmd).










