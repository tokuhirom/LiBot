requires 'Pod::PerldocJp';
requires 'Text::Shorten';
requires 'JSON';
requires 'ANyEvent::IRC';
requires 'Data::OptList';
requires 'Mouse';
requires 'GDBM_File';
requires 'Log::Pony';

on 'test' => sub {
    requires 'Test::AllModules';
};
