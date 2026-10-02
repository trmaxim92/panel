<!--LEFT MENU-->
<div class="ui vertical menu left inverted {{ sidebarClass }} ss-sidebar" id="{{sidebarId}}">
    {% if showLogo %}
        <a class="item logo top-left-logo ss-brand ss-brand-sidebar" href="{{ logoHref }}">
            <span class="ss-brand-mark" aria-hidden="true"></span>
            <span class="ss-brand-text">miko</span>
        </a>
    {% endif %}
    {{ elements.getMenu() }}
</div>
<!--/LEFT MENU-->
