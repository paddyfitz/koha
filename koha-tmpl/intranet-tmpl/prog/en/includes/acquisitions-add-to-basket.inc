<fieldset id="acqui_basket_add">
    <legend>Add Order To Basket</legend>
    <form action="/cgi-bin/koha/acqui/neworderbiblio.pl" method="post">
        <input type="hidden" name="booksellerid" value="<!-- TMPL_VAR NAME="booksellerid" -->" />
        <input type="hidden" name="basketno" value="<!-- TMPL_VAR NAME="basketno" -->" />
        <ul><li><label for="q">From an existing record: </label><input id="q" type="text"  size="25" name="q" />
        <input type="submit" class="submit" value="Search" /></li>
        <li><a href="/cgi-bin/koha/acqui/newordersuggestion.pl?booksellerid=<!-- TMPL_VAR NAME="booksellerid" -->&amp;basketno=<!-- TMPL_VAR NAME="basketno" -->">From a Suggestion</a></li>
        <li><a href="/cgi-bin/koha/acqui/neworderempty.pl?booksellerid=<!-- TMPL_VAR NAME="booksellerid" -->&amp;basketno=<!-- TMPL_VAR NAME="basketno" -->">From a new (empty) record</a></li>
        <li><a href="/cgi-bin/koha/acqui/z3950_search.pl?booksellerid=<!-- TMPL_VAR NAME="booksellerid" -->&amp;basketno=<!-- TMPL_VAR NAME="basketno" -->">From an external source</a></li>
        <li><a href="/cgi-bin/koha/acqui/addorderiso2709.pl?booksellerid=<!-- TMPL_VAR NAME="booksellerid" -->&amp;basketno=<!-- TMPL_VAR NAME="basketno" -->"> From a staged file</a></li>
        </ul>
    </form>
</fieldset>