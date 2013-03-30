requires perl => '5.010000';
requires 'Pod::PerldocJp';
requires 'Text::Shorten';
requires 'JSON';
requires 'Data::OptList';
requires 'Mouse';
requires 'Log::Pony';
requires 'HTTP::Response::Encoding';
requires 'HTML::Entities';

# Handler::Karma
requires 'DB_File';

on 'test' => sub {
    requires 'Test::AllModules';
};
