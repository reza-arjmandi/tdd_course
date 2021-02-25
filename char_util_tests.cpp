#include "gmock/gmock.h"

#include <string>
#include "include/CharUtil.h"

using namespace std;
using namespace testing;

TEST(AChar, is_a_vowel_for_six_specific_letters) {
   ASSERT_TRUE(CharUtil::is_vowel('A'));
   ASSERT_TRUE(CharUtil::is_vowel('E'));
   ASSERT_TRUE(CharUtil::is_vowel('I'));
   ASSERT_TRUE(CharUtil::is_vowel('O'));
   ASSERT_TRUE(CharUtil::is_vowel('U'));
   ASSERT_TRUE(CharUtil::is_vowel('Y'));
}

TEST(AChar, is_a_vowel_for_lowercase_letters) {
   ASSERT_TRUE(CharUtil::is_vowel('a'));
   ASSERT_TRUE(CharUtil::is_vowel('e'));
   ASSERT_TRUE(CharUtil::is_vowel('i'));
   ASSERT_TRUE(CharUtil::is_vowel('o'));
   ASSERT_TRUE(CharUtil::is_vowel('u'));
   ASSERT_TRUE(CharUtil::is_vowel('y'));
}

TEST(AChar, is_not_a_vowel_for_any_other_character) {
   ASSERT_FALSE(CharUtil::is_vowel('b'));
}

TEST(AChar, answers_appropriate_upper_case_letter) {
   ASSERT_THAT(CharUtil::upper('a'), Eq("A"));
}

TEST(AChar, handles_already_uppercased_letters) {
   ASSERT_THAT(CharUtil::upper('B'), Eq("B"));
}

TEST(AChar, ignores_non_letters_when_uppercasing) {
   ASSERT_THAT(CharUtil::upper('+'), Eq("+"));
}

TEST(AChar, answers_appropriate_lower_case_letter) {
   ASSERT_THAT(CharUtil::lower('A'), Eq('a'));
}

TEST(AChar, handles_already_lowercased) {
   ASSERT_THAT(CharUtil::lower('b'), Eq('b'));
}

TEST(AChar, ignores_non_letters_when_lowercasing) {
   ASSERT_THAT(CharUtil::lower('+'), Eq('+'));
}
