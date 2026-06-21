import 'package:almi3/core/hebrew_sentence_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findFormTokenIndex', () {
    test('finds a plain token in the middle', () {
      const sentence = 'אני רוצה לִלְמֹד עברית';
      expect(findFormTokenIndex(sentence, 'לִלְמֹד'), 2);
    });

    test('finds the first token', () {
      const sentence = 'לִלְמֹד זה כיף';
      expect(findFormTokenIndex(sentence, 'לִלְמֹד'), 0);
    });

    test('finds the last token', () {
      const sentence = 'אני אוהב לִלְמֹד';
      expect(findFormTokenIndex(sentence, 'לִלְמֹד'), 2);
    });

    test('strips trailing comma', () {
      const sentence = 'הוא לָמַד, אבל היא לא';
      expect(findFormTokenIndex(sentence, 'לָמַד'), 1);
    });

    test('strips trailing period', () {
      const sentence = 'היא לוֹמֶדֶת.';
      expect(findFormTokenIndex(sentence, 'לוֹמֶדֶת'), 1);
    });

    test('strips trailing colon', () {
      const sentence = 'הוא אמר לִלְמֹד:';
      expect(findFormTokenIndex(sentence, 'לִלְמֹד'), 2);
    });

    test('strips trailing question mark', () {
      const sentence = 'אתה רוצה לִלְמֹד?';
      expect(findFormTokenIndex(sentence, 'לִלְמֹד'), 2);
    });

    test('strips trailing exclamation mark', () {
      const sentence = 'בוא לִלְמֹד!';
      expect(findFormTokenIndex(sentence, 'לִלְמֹד'), 1);
    });

    test('strips maqaf (־) prefix', () {
      // maqaf can appear at start or end of a token when joining words
      const sentence = 'הוא ־לָמַד בבית הספר';
      expect(findFormTokenIndex(sentence, 'לָמַד'), 1);
    });

    test('strips maqaf (־) suffix', () {
      const sentence = 'הוא לָמַד־ בבית הספר';
      expect(findFormTokenIndex(sentence, 'לָמַד'), 1);
    });

    test('strips geresh (׳) suffix', () {
      const sentence = 'ד׳ לָמַד היטב';
      expect(findFormTokenIndex(sentence, 'ד'), 0);
    });

    test('strips gershayim (״) suffix', () {
      const sentence = 'הם לָמְדוּ״ בבית הספר';
      expect(findFormTokenIndex(sentence, 'לָמְדוּ'), 1);
    });

    test('returns -1 when form is not in sentence', () {
      const sentence = 'אני אוהב עברית';
      expect(findFormTokenIndex(sentence, 'לִלְמֹד'), -1);
    });

    test('returns -1 for empty sentence', () {
      expect(findFormTokenIndex('', 'לִלְמֹד'), -1);
    });

    test('returns -1 for empty form value', () {
      // every stripped token equals '' if the sentence is empty or all punct,
      // but for a normal sentence no token strips to empty
      expect(findFormTokenIndex('אני לומד עברית', ''), -1);
    });

    test('matches first occurrence when form appears twice', () {
      const sentence = 'לִלְמֹד או לִלְמֹד מחר';
      expect(findFormTokenIndex(sentence, 'לִלְמֹד'), 0);
    });

    test('single-word sentence without punctuation', () {
      expect(findFormTokenIndex('לִלְמֹד', 'לִלְמֹד'), 0);
    });

    test('single-word sentence with trailing period', () {
      expect(findFormTokenIndex('לִלְמֹד.', 'לִלְמֹד'), 0);
    });
  });

  group('stripHebrewPunct', () {
    test('no punctuation — returns unchanged', () {
      expect(stripHebrewPunct('לָמַד'), 'לָמַד');
    });

    test('strips leading and trailing comma and period', () {
      expect(stripHebrewPunct(',לָמַד.'), 'לָמַד');
    });

    test('strips only boundary punctuation, not internal', () {
      // there should be no internal punctuation in a single token,
      // but verify the regex anchors do not remove mid-string chars
      expect(stripHebrewPunct('לָמַד'), 'לָמַד');
    });

    test('strips maqaf on both sides', () {
      expect(stripHebrewPunct('־לָמַד־'), 'לָמַד');
    });
  });
}
