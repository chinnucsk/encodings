%% Copyright (c) 2009, Dmitry Vasiliev <dima@hlabs.spb.ru>
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions are met:
%%
%% * Redistributions of source code must retain the above copyright notice,
%%   this list of conditions and the following disclaimer.
%% * Redistributions in binary form must reproduce the above copyright notice,
%%   this list of conditions and the following disclaimer in the documentation
%%   and/or other materials provided with the distribution.
%% * Neither the name of the copyright holders nor the names of its
%%   contributors may be used to endorse or promote products derived from this
%%   software without specific prior written permission. 
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
%% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
%% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
%% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
%% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
%% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
%% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
%% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
%% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%% POSSIBILITY OF SUCH DAMAGE.
%%
%% @doc Tests
%%
-module(encodings_tests).
-author("Dmitry Vasiliev <dima@hlabs.spb.ru>").
-vsn("0.1").

-export([test_aliases/1, test_encode_decode/3, setup/0, cleanup/1]).

-include_lib("eunit/include/eunit.hrl").


%%
%% Auxiliary functions
%%

test_encoding(Aliases, Filename) ->
    {Bytes, Unicode, DecoderErrors, EncoderErrors} = read_tests(Filename),
    test_aliases(Aliases),
    Alias = hd(Aliases),
    test_encode_decode(Alias, Bytes, Unicode),
    test_errors(DecoderErrors, fun (I) -> encodings:decode(I, Alias) end),
    test_errors(EncoderErrors, fun (I) -> encodings:encode(I, Alias) end),
    ok.


test_aliases([Alias | Aliases]) ->
    {ok, Encoder} = encodings:getencoder(Alias),
    {ok, Decoder} = encodings:getdecoder(Alias),
    test_aliases(Aliases, Encoder, Decoder).

test_aliases([], _, _) ->
    true;
test_aliases([Alias | Aliases], Encoder, Decoder) ->
    {ok, Encoder} = encodings:getencoder(Alias),
    {ok, Decoder} = encodings:getdecoder(Alias),
    test_aliases(Aliases, Encoder, Decoder).


test_encode_decode(Alias, Bytes, Unicode) ->
    Unicode = encodings:decode(Bytes, Alias),
    Bytes = encodings:encode(Unicode, Alias),
    {ok, Encoder} = encodings:getencoder(Alias),
    {ok, Decoder} = encodings:getdecoder(Alias),
    Unicode = Decoder(Bytes),
    Bytes = Encoder(Unicode).


test_errors([], _) ->
    ok;
test_errors([{Input, Result} | Errors], Fun) ->
    Result = Fun(Input),
    test_errors(Errors, Fun).


read_tests(Filename) ->
    Path = filename:join([filename:dirname(?FILE), "tests", Filename]),
    {ok, Terms} = file:consult(Path),
    read_tests(Terms, <<>>, [], [], []).

read_tests([], String, Unicode, DecodeErrors, EncodeErrors) ->
    {String, lists:reverse(Unicode), DecodeErrors, EncodeErrors};
read_tests([{decode, Error} | Tail],
        String, Unicode, DecodeErrors, EncodeErrors) ->
    read_tests(Tail, String, Unicode, [Error | DecodeErrors], EncodeErrors);
read_tests([{encode, Error} | Tail],
        String, Unicode, DecodeErrors, EncodeErrors) ->
    read_tests(Tail, String, Unicode, DecodeErrors, [Error | EncodeErrors]);
read_tests([{Byte, Char} | Tail],
        String, Unicode, DecodeErrors, EncodeErrors) ->
    read_tests(Tail, <<String/binary,Byte>>,
        [Char | Unicode], DecodeErrors, EncodeErrors).


test_register() ->
    {error, badarg} = encodings:getencoder("encoding"),
    Encoder = fun (U) -> <<"Encoded ", (list_to_binary(U))/binary>> end,
    Decoder = fun (S) -> "Decoded " ++ binary_to_list(S) end,
    Aliases = ["encoding", "an_encoding"],
    encodings:register({functions, Aliases, Encoder, Decoder}),
    {ok, Aliases, Encoder, Decoder} = encodings:lookup("encoding"),
    {ok, Aliases, Encoder, Decoder} = encodings:lookup("an-encoding"),
    <<"Encoded Unicode">> = Encoder("Unicode"),
    "Decoded String" = Decoder(<<"String">>),
    ok.


test_register_module() ->
    encodings:register({module, enc_ascii}),
    {ok, _} = encodings:getencoder("ascii"),
    {ok, _} = encodings:getdecoder("ascii"),
    ok.


test_registration_override() ->
    <<"Unicode">> = encodings:encode("Unicode", ascii),
    "String" = encodings:decode(<<"String">>, ascii),
    Encoder = fun (U) -> "Encoded " ++ U end,
    Decoder = fun (S) -> "Decoded " ++ binary_to_list(S) end,
    true = encodings:register({functions, [ascii], Encoder, Decoder}),
    "Encoded Unicode" = encodings:encode("Unicode", ascii),
    "Decoded String" = encodings:decode(<<"String">>, ascii),
    ok.


test_register_error_handler() ->
    Handler = fun (_, Error) -> Error end,
    true = encodings:register_error(myhandler, Handler),
    {ok, Handler} = encodings:lookup_error(myhandler),
    ok.


%%
%% Tests
%%

setup() ->
    encodings:start().

cleanup(_) ->
    encodings:stop().


encodings_test_() -> {setup, fun setup/0, fun cleanup/1, [
    ?_assertEqual(ok, test_encoding([ascii, "ascii", "ASCII", "646",
        "ansi-x3.4-1968", "ansi-x3-4-1986", "cp367", "csascii",
        "IBM367", "ISO646-US", "ISO-646.IRV 1991", "iso-ir-6",
        "US", "US-ASCII"], "ascii.txt")),
    ?_assertEqual(ok, test_encoding([latin1, iso8859_1,
        "8859", "CP819", "csisolatin1", "IBM819", "iso8859", "iso8859-1",
        "ISO-8859-1", "ISO-8859-1 1987", "ISO IR-100", "L1", "LATIN",
        "LATIN1", "latin1"], "iso8859-1.txt")),
    ?_assertEqual(ok, test_encoding([cp1251, windows1251,
        "cp1251", "windows-1251", "1251"], "cp1251.txt")),
    ?_assertEqual(ok, test_encoding([cp866, "cp866", "866",
        "IBM866", "CSIBM866"], "cp866.txt")),
    ?_assertEqual(ok, test_encoding([koi8r, "koi8-r", "KOI8-R", "CSKOI8R"],
        "koi8-r.txt")),
    ?_assertEqual(ok, test_encoding([iso8859_5, "ISO8859-5",
        "csisolatincyrillic", "cyrillic", "ISO-8859-5", "ISO-8859-5 1988",
        "ISO IR-144"], "iso8859-5.txt"))
    ]}.


registration_test_() -> {setup, fun setup/0, fun cleanup/1, [
    ?_assertEqual(ok, test_register()),
    ?_assertEqual(ok, test_register_module()),
    ?_assertEqual(ok, test_registration_override())
    ]}.


normalize_encoding_test_() -> [
    ?_assertEqual(encoding, encodings:normalize_encoding(encoding)),
    ?_assertEqual("encoding", encodings:normalize_encoding("encoding")),
    ?_assertEqual("encoding", encodings:normalize_encoding(" encoding -_")),
    ?_assertEqual("encoding_1", encodings:normalize_encoding("encoding - 1"))
    ].


error_handler_test_() -> {setup, fun setup/0, fun cleanup/1, [
    ?_assertEqual(ok, test_register_error_handler()),
    ?_assertEqual([16#2014],
        encodings:decode(<<16#97, 16#98, 16#99>>, "1251", ignore)),
    ?_assertEqual(<<16#97>>,
        encodings:encode([16#2014, 16#fffd, 16#2122], "1251", ignore))
    %?_assertEqual([16#2014, 16#2122],
    %    encodings:decode(<<16#97, 16#98, 16#99>>, "1251", skip)),
    %?_assertEqual(<<16#97, 16#99>>,
    %    encodings:encode([16#2014, 16#fffd, 16#2122], "1251", skip))
    ]}.
