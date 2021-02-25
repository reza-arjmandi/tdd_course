#include "gmock/gmock.h"

#include "include/StringUtil.h"

using namespace std;
using namespace testing;

TEST(AString, answers_head_as_its_first_letter) {
   ASSERT_THAT(StringUtil::head("xyz"), Eq('x'));
}

TEST(AString, answers_head_as_empty_when_empty) {
   ASSERT_THAT(StringUtil::head(""), Eq('\0'));
}

TEST(AString, answers_tail_as_all_letters_after_head) {
   ASSERT_THAT(StringUtil::tail("xyz"), Eq("yz"));
}

TEST(AString, answers_tail_as_empty_when_empty) {
   ASSERT_THAT(StringUtil::tail(""), Eq(""));
}

TEST(AString, answers_tail_as_empty_when_contains_only_one_character) {
   ASSERT_THAT(StringUtil::tail("X"), Eq(""));
}
