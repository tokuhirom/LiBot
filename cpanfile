requires 'Pod::PerldocJp';
requires 'Text::Shorten';
requires 'JSON';
requires 'ANyEvent::IRC';
requires 'Data::OptList';
requires 'Mouse';
requires 'GDBM_File';

on 'test' => sub {
    requires 'Test::AllModules';
};
