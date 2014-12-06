-module(netlink_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(VETH_INTF_1, "veth100").
-define(VETH_INTF_2, "veth200").
-define(TAP_INTF, "tap100").

%%--------------------------------------------------------------------
%% Suite configuration
%%--------------------------------------------------------------------

all() ->
    [{group, veth_intefaces},
     {group, tap_interfaces}].

groups() ->
    [{veth_intefaces, [sequence],
      [should_read_correct_veth_interface_operation_state,
       should_notify_about_veth_interfaces_flags]},
     {tap_interfaces, [sequence],
      [should_notify_about_tap_interfaces_flags]}].

%%--------------------------------------------------------------------
%% Init & teardown
%%--------------------------------------------------------------------

init_per_suite(Config) ->
    netlink:start(),
    Config.

end_per_suite(_Config) ->
    netlink:stop().

init_per_group(veth_intefaces, Config) ->
    case interfaces_exist_in_the_os([?VETH_INTF_1, ?VETH_INTF_2]) of
        false ->
            create_veth_interfaces_pair(?VETH_INTF_1, ?VETH_INTF_2);
        true ->
            ct:fail("Interfaces ~p and ~p already exist",
                    [?VETH_INTF_1, ?VETH_INTF_2])
    end,
    [{intf_to_del, ?VETH_INTF_1} | Config];
init_per_group(tap_interfaces, Config) ->
    case interfaces_exist_in_the_os([?TAP_INTF]) of
        false ->
            create_tap_interface(?TAP_INTF);
        true ->
            ct:fail("Interface ~p already exist", [?TAP_INTF])
    end,
    [{intf_to_del, ?TAP_INTF} | Config].

end_per_group(_, Config) ->
    interface_del(proplists:get_value(intf_to_del, Config)).

%%--------------------------------------------------------------------
%% Tests
%%--------------------------------------------------------------------

should_read_correct_veth_interface_operation_state(Config) ->
    %% veth interface is in operational state up if its' peer is up too
    interface_up(?VETH_INTF_2),
    should_read_correct_interface_operstate(?VETH_INTF_1, Config),
    interface_down(?VETH_INTF_2).

should_read_correct_interface_operstate(Intf, Config) ->
    [begin
         %% GIVEN
         case State of
             down ->
                 interface_down(Intf);
             up ->
                 interface_up(Intf)
         end,
         {ok, Ref} = netlink:subscribe(Intf),

         %% WHEN
         netlink:invalidate(Intf, [operstate]),
         netlink:get_match(link, unspec, [{operstate, native, State}]),

         %% THEN
         receive
             {netlink, Ref, Intf, operstate, _, Operstate} ->
                 ?assertEqual(State, Operstate)
         after
             500 ->
                 ct:fail("No notification about ~p ~n", [Intf])
         end
     end || State <- [down, up]].

should_notify_about_veth_interfaces_flags(_Config) ->
    should_notify_about_interfaces_flags(?VETH_INTF_1).

should_notify_about_tap_interfaces_flags(_Config) ->
    should_notify_about_interfaces_flags(?TAP_INTF).

should_notify_about_interfaces_flags(Intf) ->
    %% GIVEN
    interface_down(Intf),
    {ok, Ref} = netlink:subscribe(Intf, [flags]),

    %% WHEN
    interface_up(Intf),
    interface_down(Intf),

    %% THEN
    assert_interface(went_up, Ref, Intf),
    assert_interface(went_down, Ref, Intf),
    netlink:unsubscribe(Ref).

assert_interface(ExceptedAction, Ref, Intf) ->
    receive
        {netlink, Ref, Intf, flags, OldFlags, NewFlags} ->
            assert_interface_flags_indicate(ExceptedAction, OldFlags, NewFlags)
    after
        500 ->
            ct:fail("No notification about ~p ~n", [Intf])
    end.

assert_interface_flags_indicate(went_up, OldFlags, NewFlags) ->
    ?assertNot(lists:member(up, OldFlags)),
    ?assert(lists:member(up, NewFlags));
assert_interface_flags_indicate(went_down, OldFlags, NewFlags) ->
    ?assert(lists:member(up, OldFlags)),
    ?assertNot(lists:member(up, NewFlags)).

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

interfaces_exist_in_the_os(IntfList) ->
    {ok, Addrs} = inet:getifaddrs(),
    lists:any(fun(Intf) ->
                      lists:keyfind(Intf, 1, Addrs)
              end, IntfList).

create_veth_interfaces_pair(Intf1, Intf2) ->
    Cmd = io_lib:format("ip link add ~s type veth peer name ~s",
                        [Intf1, Intf2]),
    os:cmd(Cmd).

create_tap_interface(Intf) ->
    Cmd = io_lib:format("tunctl -t ~p", [Intf]),
    os:cmd(Cmd).

interface_down(Intf) ->
    Cmd = io_lib:format("ip link set dev ~s down", [Intf]),
    os:cmd(Cmd).

interface_up(Intf) ->
    Cmd = io_lib:format("ip link set dev ~s up", [Intf]),
    os:cmd(Cmd).

interface_del(Intf) ->
    Cmd = io_lib:format("ip link del ~s", [Intf]),
    os:cmd(Cmd).








