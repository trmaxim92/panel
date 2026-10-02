<div id="extensions-table-container" class="ss-ext-page">
    <div class="ss-ext-toolbar">
        <div class="ss-ext-actions">
            {% if isAllowed('save') %}
                <div class="ui buttons">
                    {{ link_to("extensions/modify", '<i class="plus icon"></i> '~t._('ex_AddNewExtension'), "class": "ui blue button", "id":"add-new-button") }}
                    <div class="ui floating dropdown blue icon button" id="bulk-actions-dropdown">
                        <i class="dropdown icon"></i>
                        <div class="menu">
                            <a class="item" href="{{ url('extensions/bulkupload#import') }}">
                                <i class="upload icon"></i>
                                {{ t._('ex_ImportFromCSV') }}
                            </a>
                            <a class="item" href="{{ url('extensions/bulkupload#export') }}">
                                <i class="download icon"></i>
                                {{ t._('ex_ExportToCSV') }}
                            </a>
                            <a class="item" href="{{ url('extensions/bulkupload#template') }}">
                                <i class="file outline icon"></i>
                                {{ t._('ex_DownloadTemplate') }}
                            </a>
                        </div>
                    </div>
                </div>
            {% endif %}
        </div>
        <div class="ss-ext-search">
            <div class="ui search left icon fluid input" id="search-extensions-input">
                <i class="search link icon" id="search-icon"></i>
                <input type="search" id="global-search" name="global-search" placeholder="{{ t._('ex_EnterSearchPhrase') }}"
                       aria-controls="extensions-table" class="prompt" autocomplete="off">
                <div class="results"></div>
            </div>
            <div class="ui basic floating search dropdown button" id="page-length-select">
                <i class="filter icon"></i>
                <div class="text">{{ t._('ex_CalculateAutomatically') }}</div>
                <i class="dropdown icon"></i>
                <div class="menu">
                    <div class="item" data-value="auto">{{ t._('ex_CalculateAutomatically') }}</div>
                    <div class="item" data-value="25">{{ t._('ex_ShowOnlyRows', {'rows':25}) }}</div>
                    <div class="item" data-value="50">{{ t._('ex_ShowOnlyRows', {'rows':50}) }}</div>
                    <div class="item" data-value="100">{{ t._('ex_ShowOnlyRows', {'rows':100}) }}</div>
                    <div class="item" data-value="500">{{ t._('ex_ShowOnlyRows', {'rows':500}) }}</div>
                </div>
            </div>
        </div>
    </div>

    <table class="ui selectable unstackable table" id="extensions-table">
        <thead>
        <tr>
            <th></th>
            <th>{{ t._('ex_Name') }}</th>
            <th class="center aligned">{{ t._('ex_Extension') }}</th>
            <th class="center aligned">{{ t._('ex_Mobile') }}</th>
            <th class="">{{ t._('ex_Email') }}</th>
            <th></th>
        </tr>
        </thead>
        <tbody>
        </tbody>
    </table>
</div>

<div id="extensions-placeholder" style="display: none; margin-top: 2em;">
    {% set dropdownItems = [
        {'link': url('extensions/bulkupload#import'), 'icon': 'upload', 'text': t._('ex_ImportFromCSV')},
        {'link': url('extensions/bulkupload#export'), 'icon': 'download', 'text': t._('ex_ExportToCSV')},
        {'link': url('extensions/bulkupload#template'), 'icon': 'file outline', 'text': t._('ex_DownloadTemplate')}
    ] %}
    {{ partial("partials/emptyTablePlaceholder", [
        'icon': 'search',
        'title': t._('ex_EmptyTableTitle'),
        'description': t._('ex_EmptyTableDescription'),
        'addButtonText': '<i class="plus icon"></i> '~t._('ex_AddNewExtension'),
        'addButtonLink': 'extensions/modify',
        'showButton': isAllowed('save'),
        'documentationLink': 'https://wiki.mikopbx.com/extensions',
        'dropdownItems': dropdownItems
    ]) }}
</div>

<table class="template" style="display: none">
    <tbody>
    <tr class="extension-row-tpl">
        <td class="disability center aligned extension-status"><i class="spinner loading icon"></i></td>
        <td class="disability collapsing"><img src="#" class="ui avatar image"></td>
        <td class="center aligned disability number"></td>
        <td class="center aligned disability mobile">
            <div class="ui transparent input">
                <input class="mobile-number-input" readonly="readonly" type="text" value="">
            </div>
        </td>
        <td class="disability email"></td>
        {{ partial("partials/tablesbuttons",
            [
                'id': '',
                'clipboard' : '#',
                'edit' : 'extensions/modify/',
                'delete': 'extensions/delete/']) }}
    </tr>
    </tbody>

</table>
