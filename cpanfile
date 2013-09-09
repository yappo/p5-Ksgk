requires 'perl', '5.008005';

requires 'Caroline',              '0';
requires 'Class::Accessor::Lite', '0';
requires 'File::stat',            '0';
requires 'String::CamelCase',     '0';
requires 'Path::Tiny',            '0';
requires 'Text::Xslate',          '0';

on test => sub {
    requires 'Test::More', '0.88';
};
