#pragma once

#include <unordered_map>

class Soundex {

public:

    std::string encode(const std::string& word) {
        return zero_pad(upper(head(word)) + tail(encoded_digits(word)));
    }

    std::string encoded_digit(char letter) const {
        std::unordered_map<char, std::string>  encodings{
          {'b', "1"}, {'f', "1"}, {'p', "1"}, {'v', "1"},
          {'c', "2"}, {'g', "2"}, {'j', "2"}, {'k', "2"}, {'q', "2"}, {'s', "2"}, {'x', "2"}, {'z', "2"}, 
          {'d', "3"}, {'t', "3"},
          {'l', "4"},
          {'m', "5"}, {'n', "5"},
          {'r', "6"}
        };
        auto it = encodings.find(lower(letter));
        return it == encodings.end() ? NotADigit : it->second;
    }

private:

    const std::size_t MaxCodeLength {4};
    const std::string NotADigit {"*"};

    std::string upper(char ch) {
        return std::string(1, std::toupper(static_cast<unsigned char>(ch)));
    }

    char lower(char ch) const {
        return std::tolower(static_cast<unsigned char>(ch));
    }
    char head(const std::string& word) const {
        return word.front();
    }

    std::string tail(const std::string& word) const {
        return word.substr(1);
    }

    std::string encoded_digits(const std::string& word) {
        std::string encoding;
        encode_head(encoding, word);
        encode_tail(encoding, word);
        return encoding;
    }

    void encode_head(std::string& encoding, const std::string& word) const {
        encoding += encoded_digit(word.front());
    }

    void encode_tail(std::string& encoding, const std::string& word) const {
        for(auto letter : tail(word)) {
            if(!is_complete(encoding)) {
                encode_letter(encoding, letter);
            }
        }
    }

    void encode_letter(std::string& encoding, char letter) const {
        auto digit = encoded_digit(letter);
        if(digit != NotADigit && last_digit(encoding) != digit) {
            encoding += digit;
        }
    }

    std::string last_digit(const std::string& encoding) const {
        if(encoding.empty()) {
            return NotADigit;
        }
        return std::string(1, encoding.back());
    }

    bool is_complete(const std::string& encoding) const {
        return encoding.length() == MaxCodeLength;
    }

    std::string zero_pad(const std::string& word) {
        auto zeros_needed = MaxCodeLength - word.length();
        return word + std::string(zeros_needed, '0');
    }

};