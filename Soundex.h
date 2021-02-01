#pragma once

#include <unordered_map>

class Soundex {

public:

    std::string encode(const std::string& word) {
        return zero_pad(head(word) + encoded_digits(tail(word)));
    }

private:

    const std::size_t MaxCodeLength {4};

    char head(const std::string& word) const {
        return word.front();
    }

    std::string tail(const std::string& word) const {
        return word.substr(1);
    }

    std::string encoded_digits(const std::string& word) {
        std::string encoding;
        for(auto letter : word) {
            if(is_complete(encoding)) {
                break;
            }
            encoding += encoded_digit(letter);
        }
        return encoding;
    }

    bool is_complete(const std::string& encoding) const {
        return encoding.length() == MaxCodeLength - 1;
    }

    std::string encoded_digit(char letter) {
        std::unordered_map<char, std::string>  encodings{
          {'b', "1"}, {'f', "1"}, {'p', "1"}, {'v', "1"},
          {'c', "2"}, {'g', "2"}, {'j', "2"}, {'k', "2"}, {'q', "2"}, {'s', "2"}, {'x', "2"}, {'z', "2"}, 
          {'d', "3"}, {'t', "3"},
          {'l', "4"},
          {'m', "5"}, {'n', "5"},
          {'r', "6"}
        };
        auto it = encodings.find(letter);
        return it == encodings.end() ? "" : it->second;
    }
    

    std::string zero_pad(const std::string& word) {
        auto zeros_needed = MaxCodeLength - word.length();
        return word + std::string(zeros_needed, '0');
    }

};