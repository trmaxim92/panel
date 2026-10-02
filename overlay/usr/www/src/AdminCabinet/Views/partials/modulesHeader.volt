{# SkyScale — module page header without vendor logo #}
<div class="ss-mod-head">
    <div class="ss-mod-head-ico">
        {{ elements.getIconByController(controllerClass) }}
    </div>
    <div class="ss-mod-head-titles">
        <h1>{{ t._('Breadcrumb'~controllerName) }}</h1>
        <p>
            {{ t._('SubHeader'~controllerName) }}
            {% if module['version'] is defined %}
                <span class="ss-mod-ver">v{{ module['version'] }}</span>
            {% endif %}
            <a class="wiki-help-link" href="#"
               data-controller="{{ controllerName }}" data-action="{{ actionName }}"
               {% if globalModuleUniqueId %}data-module-id="{{ globalModuleUniqueId }}"{% endif %}
               data-content="{{ t._("GoToWikiDocumentation") }}"
               data-variation="wide"><i class="question circle outline icon"></i></a>
        </p>
    </div>
</div>
{{ partial("PbxExtensionModules/hookVoltBlock",['arrayOfPartials':hookVoltBlock('Header')]) }}
{% if globalModuleUniqueId == 'ModuleMonitorActiveCalls' %}
<script src="{{ url() }}assets/js/pbx/ModuleMonitorActiveCalls/monitor-active-calls.js"></script>
{% endif %}
