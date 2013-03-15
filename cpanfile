requires 'Pod::PerldocJp';
requires 'Text::Shorten';
requires 'JSON';
requires 'Data::OptList';
requires 'Mouse';
requires 'GDBM_File';
requires 'Log::Pony';
requires 'HTTP::Response::Encoding';

on 'test' => sub {
    requires 'Test::AllModules';
};
