enum GrammaticalPerson { none, first, second, third }

enum GrammaticalGender { none, masculine, feminine }

enum Plurality { singular, plural, none }

enum Tense { present, past, future, imperative, infinitive }

Tense tenseFromJson(int i) => Tense.values[i];

GrammaticalPerson personFromJson(int i) => GrammaticalPerson.values[i];

Plurality pluralityFromJson(int i) => Plurality.values[i];

GrammaticalGender genderFromJson(int i) => GrammaticalGender.values[i];
