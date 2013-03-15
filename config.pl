+{
    providers => [
        'Lingr' => {
            host => '127.0.0.1',
            port => 1199,
        },
    ],
    'plugins' => [
        Karma => {
            path => 'karma.db',
        },
        'LLEval',
        'IkachanForwarder' => {
            url => 'http://127.0.0.1:4979',
            channel => '#hiratara',
        },
        'PerldocJP',
    ],
};
