#pragma once

#include <unordered_map>

#include "StringUtil.h"
#include "CharUtil.h"

class Soundex {

public:

    const std::size_t MaxCodeLength {4};

    std::string encode(const std::string& word);
    std::string encoded_digit(char letter) const;

private:

    const std::string NotADigit {"*"};

    std::string encoded_digits(const std::string& word);
    void encode_head(std::string& encoding, const std::string& word) const;
    void encode_tail(std::string& encoding, const std::string& word) const;
    void encode_letter(
        std::string& encoding, char letter, char last_letter) const;
    std::string last_digit(const std::string& encoding) const;
    bool is_complete(const std::string& encoding) const;

};