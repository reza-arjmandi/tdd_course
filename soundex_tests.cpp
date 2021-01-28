#include "gtest/gtest.h"
#include "gmock/gmock.h"

#include <string>

using namespace testing;

class Soundex {

public:

    std::string encode(const std::string& var) {
        return var;
    }

};
class SoundexEncoding : public Test {

public:

};

TEST_F(SoundexEncoding, retains_sole_letter_of_one_letter_word) {
    Soundex soundex;
    auto encoding = soundex.encode("A");
    ASSERT_THAT(encoding, Eq("A"));
}