import 'package:almi3/core/enums.dart';

String grammaticIconAsset(GrammaticalPerson person, Plurality plurality, GrammaticalGender gender) {
  if (person == GrammaticalPerson.none) return 'assets/icons/grammatic/inf.svg';
  if (person == GrammaticalPerson.first) {
    return plurality == Plurality.plural
        ? 'assets/icons/grammatic/first-pl-o.svg'
        : 'assets/icons/grammatic/first-sing-o.svg';
  }
  if (person == GrammaticalPerson.second) {
    if (plurality == Plurality.plural) {
      return gender == GrammaticalGender.feminine
          ? 'assets/icons/grammatic/sec-pl-fem-o.svg'
          : 'assets/icons/grammatic/sec-pl-masc-o.svg';
    }
    return gender == GrammaticalGender.feminine
        ? 'assets/icons/grammatic/sec-sing-fem-o.svg'
        : 'assets/icons/grammatic/sec-sing-masc-o.svg';
  }
  // third
  if (gender == GrammaticalGender.none) return 'assets/icons/grammatic/third-pl-o.svg';
  if (plurality == Plurality.plural) {
    return gender == GrammaticalGender.feminine
        ? 'assets/icons/grammatic/third-pl-fem-o.svg'
        : 'assets/icons/grammatic/third-pl-masc-o.svg';
  }
  return gender == GrammaticalGender.feminine
      ? 'assets/icons/grammatic/third-sing-fem-o.svg'
      : 'assets/icons/grammatic/third-sing-masc-o.svg';
}

// Maps DB value (Hebrew niqqud or Latin) → canonical key
const _binyanKeys = {
  'הִתְפַּעֵל': 'hitpael',
  'הִפְעִיל':  'hifil',
  'הוּפְעַל':  'hufal',
  'הֻפְעַל':   'hufal',
  'נִפְעַל':   'nifal',
  'פִּעֵל':    'piel',
  'פֻּעַל':    'pual',
  'פָּעַל':    'paal',
};

String _binyanKey(String s) {
  final exact = _binyanKeys[s.trim()];
  if (exact != null) return exact;
  final lower = s.toLowerCase().replaceAll("'", '').replaceAll(' ', '');
  if (lower.contains('hitpael') || lower.contains('hitp')) return 'hitpael';
  if (lower.contains('hufal')   || lower.contains('huph')) return 'hufal';
  if (lower.contains('hifil')   || lower.contains('hiph')) return 'hifil';
  if (lower.contains('nifal')   || lower.contains('niph')) return 'nifal';
  if (lower.contains('pual'))  return 'pual';
  if (lower.contains('piel'))  return 'piel';
  return 'paal';
}

String binyanIconAsset(String binyanName) {
  switch (_binyanKey(binyanName)) {
    case 'hitpael': return 'assets/icons/binyan/binyan_hitpael.svg';
    case 'hufal':   return 'assets/icons/binyan/binyan_hufal.svg';
    case 'hifil':   return 'assets/icons/binyan/binyan_hifil.svg';
    case 'nifal':   return 'assets/icons/binyan/binyan_nifal.svg';
    case 'pual':    return 'assets/icons/binyan/binyan_pual.svg';
    case 'piel':    return 'assets/icons/binyan/binyan_piel.svg';
    default:        return 'assets/icons/binyan/binyan_paal.svg';
  }
}

String binyanDisplayName(String binyanName) {
  switch (_binyanKey(binyanName)) {
    case 'hitpael': return 'Hitpael';
    case 'hufal':   return 'Hufal';
    case 'hifil':   return 'Hifil';
    case 'nifal':   return 'Nifal';
    case 'pual':    return 'Pual';
    case 'piel':    return 'Piel';
    default:        return 'Paal';
  }
}

// health: 0=na, 1=empty, 2=1q, 3=half, 4=3q, 5=full, 6=super
String heartIconAsset(int health) {
  switch (health) {
    case 6: return 'assets/icons/heart/heart_super.svg';
    case 5: return 'assets/icons/heart/heart_full.svg';
    case 4: return 'assets/icons/heart/heart_3q.svg';
    case 3: return 'assets/icons/heart/heart_half.svg';
    case 2: return 'assets/icons/heart/heart_1q.svg';
    case 1: return 'assets/icons/heart/heart_empty.svg';
    default: return 'assets/icons/heart/heart_na.svg';
  }
}
