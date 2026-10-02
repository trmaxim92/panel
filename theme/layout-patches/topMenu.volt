<!--TOP MENU-->
<div class="ui fixed inverted menu ss-topbar">
    <a class="ss-brand hide-on-mobile" href="{{ logoHref }}" id="top-left-logo">
        <span class="ss-brand-mark" aria-hidden="true"></span>
        <span class="ss-brand-text">miko</span>
    </a>

    <div class="ui item black launch left floated fixed button ss-topbar-burger" id="sidebar-menu-button">
        <i class="content icon"></i>
        <span class="text">{{ t._("topMenu_SidebarButton") }}</span>
    </div>

    <div class="ss-topbar-search-wrap">
        <div class="ui right aligned selection dropdown search item" id="top-menu-search">
            <input type="hidden" name="search-result">
            <div class="ui inverted transparent icon input ss-topbar-search">
                <input class="search" autocomplete="off" tabindex="0"
                       placeholder="{{ t._("topMenu_SearchPlaceholder") }}" value="">
                <i class="search link icon"></i>
            </div>
            <div class="results"></div>
        </div>
    </div>

    <div class="ss-topbar-actions right menu">
        <a class="item ss-topbar-icon" id="show-advice-button" title="Уведомления">
            <i class="bell outline icon"></i>
            <span class="ss-topbar-badge"></span>
        </a>
        <a class="item ss-topbar-icon hide-on-tablet wiki-help-link" href="#"
           data-controller="{{ controllerName }}" data-action="{{ actionName }}"
           {% if globalModuleUniqueId %}data-module-id="{{ globalModuleUniqueId }}"{% endif %}
           data-content="{{ t._("GoToWikiDocumentation") }}" data-variation="wide">
            <i class="question circle outline icon"></i>
        </a>
        <a class="item ss-topbar-user hide-on-tablet" href="{{ urlToSupport }}" target="_blank">
            <span class="ss-avatar"><i class="user icon"></i></span>
            <span class="ss-topbar-user-label">{{ t._("topMenu_Support") }}</span>
            <i class="dropdown icon"></i>
        </a>
        <div class="item ss-topbar-lang">
            <div class="ui scrolling dropdown" id="language-selector">
                <input type="hidden" name="WebAdminLanguage" value="{{ WebAdminLanguage }}">
                <div class="text">
                    {% if availableLanguages[WebAdminLanguage] is defined %}
                        <i class="flag {{ availableLanguages[WebAdminLanguage]['flag'] }}"></i>
                        {{ availableLanguages[WebAdminLanguage]['name'] }}
                    {% endif %}
                </div>
                <i class="dropdown icon"></i>
                <div class="menu">
                    <a class="item" target="_blank" href="https://weblate.mikopbx.com/engage/mikopbx/">
                        <i class="pencil alternate icon"></i> {{ t._('lang_HelpWithTranslateIt') }}
                    </a>
                    <div class="divider"></div>
                    {% for code, info in availableLanguages %}
                        <div class="item" data-value="{{ code }}">
                            <i class="flag {{ info['flag'] }}"></i>
                            {{ info['name'] }}
                        </div>
                    {% endfor %}
                </div>
            </div>
        </div>
        <a class="item ss-topbar-logout" href="{{ url.get('session') }}/end">
            <i class="sign out icon"></i>
            <span>{{ t._("mm_Logout") }}</span>
        </a>
    </div>
</div>
<!--/ TOP MENU-->
