{# SkyScale empty table placeholder #}
<div class="ui placeholder segment ss-empty-state">
    <div class="ui icon header">
        <i class="{{ icon|default('search') }} icon"></i>
        {{ title }}
    </div>
    {% if description %}
        <div class="inline">
            <div class="ui text">
                {{ description }}
            </div>
        </div>
    {% endif %}

    {% if (showDocumentationLink is not defined or showDocumentationLink) %}
        <div style="margin-top: 1em;">
            {% if documentationLink %}
                <a href="{{documentationLink}}"
            target="_blank"
            class="ui basic tiny button prevent-word-wrap">
                <i class="question circle outline icon"></i>
                {{ t._('et_ReadDocumentation') }}
            </a>
            {% else %}
            <a href="#"
            data-controller="{{ controllerName }}"
            data-action="{{ actionName }}"
            {% if globalModuleUniqueId %}data-module-id="{{ globalModuleUniqueId }}"{% endif %}
            target="_blank"
            class="ui basic tiny button prevent-word-wrap wiki-help-link">
                <i class="question circle outline icon"></i>
                {{ t._('et_ReadDocumentation') }}
            </a>
            {% endif %}
        </div>
    {% endif %}
    {% if showButton %}
        <div style="margin-top: 1em; text-align: center;">
            {% if dropdownItems is defined and dropdownItems|length > 0 %}
                <div class="ui buttons" style="display: inline-flex;">
                    {% if addButtonLink and addButtonText %}
                        {{ link_to(addButtonLink, addButtonText, "class": "ui blue button prevent-word-wrap") }}
                    {% endif %}
                    <div class="ui floating dropdown blue icon button">
                        <i class="dropdown icon"></i>
                        <div class="menu">
                            {% for item in dropdownItems %}
                                <a class="item" href="{{ item['link'] }}">
                                    <i class="{{ item['icon'] }} icon"></i>
                                    {{ item['text'] }}
                                </a>
                            {% endfor %}
                        </div>
                    </div>
                </div>
            {% elseif addButtonLink and addButtonText %}
                {{ link_to(addButtonLink, addButtonText, "class": "ui blue button prevent-word-wrap") }}
            {% endif %}
        </div>
    {% endif %}
</div>
