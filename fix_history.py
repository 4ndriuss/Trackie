import re

file_path = r'd:\Projects\Trackie\lib\pages\history_tab.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r"'Bulan ini .*? km',", r"'Bulan ini • ${_dummyHistory.length} trip • ${numberFormat.format(totalKm)} km',", content)
content = re.sub(r"_buildMiniStat\(theme, Icons\.route, '.*? km'\),", r"_buildMiniStat(theme, Icons.route, '${numberFormat.format(trip.distanceKm)} km'),", content)
content = re.sub(r"_buildMiniStat\(theme, Icons\.speed, '.*? km/j'\),", r"_buildMiniStat(theme, Icons.speed, '${numberFormat.format(trip.avgSpeed)} km/j'),", content)
content = re.sub(r"_buildMiniStat\(theme, Icons\.people_alt_outlined, '.*?'\),", r"_buildMiniStat(theme, Icons.people_alt_outlined, '${trip.members}'),", content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
