#!/bin/bash

# Det här skriptet kan användas som exempel på hur man automatiskt hämtar poster från Libris
# Innan du använder det, se till att du fyllt i filen: etc/export.properties
#
# Lämpligen körs detta skript minut-vis m h a cron.

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/export_nix.sh.conf"

cd "$data_dir"

set -e

# Se till att vi inte kör flera instanser av skriptet samtidigt
[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || :

# Om vi kör för första gången, sätt 'nu' till start-tid
LASTRUNTIMEPATH="lastRun.timestamp"
if [ ! -e $LASTRUNTIMEPATH ]
then
    date -u +%Y-%m-%dT%H:%M:%SZ > $LASTRUNTIMEPATH
fi

# Avgör vilket tidsintervall vi ska hämta
STARTTIME=`cat $LASTRUNTIMEPATH`
STOPTIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW=$(date +%Y-%m-%dT%H:%M:%SZ)
TODAY=$(date +%Y-%m-%d)

# Hämta data
curl -s --fail -XPOST "https://libris.kb.se/api/marc_export/?from=$STARTTIME&until=$STOPTIME&deleted=ignore&virtualDelete=false" --data-binary @./export.properties > download/"$NOW".mrc

filepath="${data_dir}/download/${NOW}.mrc"

if test -s "$filepath"
then
    echo "Laddar ${NOW}.mrc"
    # Loading can fail, accept that.
    set +e
    # Ladda
    $koha_shell_path -c cd\ $koha_path/misc/migration_tools\ \&\&\ ./bulkmarcimport.pl\ -b\ -file\ \"$filepath\"\ -match_record_id\ -insert\ -update\ -c\=MARC21\ -tomarcplugin\ \"Koha::Plugin::Se::Ub::Gu::MarcImport\" $koha_instance
    set -e

    mkdir -p "${data_dir}/archive/${TODAY}"
    mv "$filepath" "${data_dir}/archive/${TODAY}/"
else
    # File was empty, removing
    echo "Inget att ladda i ${NOW}.mrc"
    rm -f "$filepath"
fi

# Om allt gick bra, uppdatera tidsstämpeln
echo $STOPTIME > $LASTRUNTIMEPATH

# DINA ÄNDRINGAR HÄR, gör något produktivt med datat i 'export.txt', t ex:
# cat export.txt
