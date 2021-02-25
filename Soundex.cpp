#include "include/Soundex.h"

std::string Soundex::encode(const std::string& word) {
    return StringUtil::zero_pad(
        CharUtil::upper(StringUtil::head(word)) 
        + StringUtil::tail(encoded_digits(word)), 
        MaxCodeLength);
}

std::string Soundex::encoded_digit(char letter) const {
    std::unordered_map<char, std::string>  encodings{
      {'b', "1"}, {'f', "1"}, {'p', "1"}, {'v', "1"},
      {'c', "2"}, {'g', "2"}, {'j', "2"}, {'k', "2"}, {'q', "2"}, 
      {'s', "2"}, {'x', "2"}, {'z', "2"}, 
      {'d', "3"}, {'t', "3"},
      {'l', "4"},
      {'m', "5"}, {'n', "5"},
      {'r', "6"}
    };
    auto it = encodings.find(CharUtil::lower(letter));
    return it == encodings.end() ? NotADigit : it->second;
}

std::string Soundex::encoded_digits(const std::string& word) {
    std::string encoding;
    encode_head(encoding, word);
    encode_tail(encoding, word);
    return encoding;
}

void Soundex::encode_head(
    std::string& encoding, const std::string& word) const {
    encoding += encoded_digit(word.front());
}

void Soundex::encode_tail(
    std::string& encoding, const std::string& word) const {
    for(auto i = 1u; i < word.length(); i++) {
        if(!is_complete(encoding)) {
            encode_letter(encoding, word[i], word[i-1]);
        }
    }
}

void Soundex::encode_letter(
    std::string& encoding, char letter, char last_letter) const {
    auto digit = encoded_digit(letter);
    if(digit != NotADigit 
    && (last_digit(encoding) != digit 
    || CharUtil::is_vowel(last_letter))) {
        encoding += digit;
    }
}

std::string Soundex::last_digit(const std::string& encoding) const {
    if(encoding.empty()) {
        return NotADigit;
    }
    return std::string(1, encoding.back());
}

bool Soundex::is_complete(const std::string& encoding) const {
    return encoding.length() == MaxCodeLength;
}
