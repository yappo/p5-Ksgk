:ksgk: CONTENTS('load_plugins', -> {
    L10N => {
        default_lang => 'en',
        po_dir       => 'po',
    },
:ksgk: })
:ksgk: CONTENTS('define_methods', -> {
sub lang { $_[0]->l10n_language_detection }
:ksgk: })
