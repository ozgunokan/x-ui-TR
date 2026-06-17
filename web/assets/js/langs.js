const supportLangs = [
    {
        name: 'English',
        value: 'en-US',
        icon: '🇺🇸',
    },
    {
        name: 'فارسی',
        value: 'fa-IR',
        icon: '🇮🇷',
    },
    {
        name: '汉语',
        value: 'zh-Hans',
        icon: '🇨🇳',
    },
    {
        name: 'Русский',
        value: 'ru-RU',
        icon: '🇷🇺',
    },
    {
        name: 'Tiếng Việt',
        value: 'vi-VN',
        icon: '🇻🇳',        
    },
    {
        name: 'Türkçe',
        value: 'tr_TR',
        icon: '🇹🇷',        
    },
];

function getLang() {
    let lang = getCookie('lang');

    if (!lang) {
        if (window.navigator) {
            lang = window.navigator.language || window.navigator.userLanguage;

            if (isSupportLang(lang)) {
                setCookie('lang', lang);
            } else {
                setCookie('lang', 'en-US');
                window.location.reload();
            }
        } else {
            setCookie('lang', 'en-US');
            window.location.reload();
        }
    }

    return lang;
}

function setLang(lang) {
    if (!isSupportLang(lang)) {
        lang = 'en-US';
    }

    setCookie('lang', lang);
    window.location.reload();
}

function isSupportLang(lang) {
    for (l of supportLangs) {
        if (l.value === lang) {
            return true;
        }
    }

    return false;
}
