#[macro_use]
extern crate rustler;

use rustler::{Env, Term};

#[rustler::nif]
pub fn calculate(input: &str) -> Result<f64, String> {
    calculate_inner(input)
}

pub fn calculate_inner(input: &str) -> Result<f64, String> {
    let tokens = tokenize(input);
    match evaluate(tokens) {
        Ok(result) => Ok(result),
        Err(e) => Err(e.to_string()),
    }
}

rustler::init!("Elixir.ShaderLlm.RustCalc", [calculate]);

#[derive(Debug, PartialEq)]
enum Token {
    Number(f64),
    Plus,
    Minus,
    Multiply,
    Divide,
    LeftParen,
    RightParen,
}

fn tokenize(input: &str) -> Vec<Token> {
    let mut tokens = Vec::new();
    let mut number_str = String::new();

    for c in input.chars() {
        match c {
            '0'..='9' | '.' => number_str.push(c),
            '+' | '-' | '*' | '/' | '(' | ')' => {
                if !number_str.is_empty() {
                    if let Ok(num) = number_str.parse::<f64>() {
                        tokens.push(Token::Number(num));
                    }
                    number_str.clear();
                }
                tokens.push(match c {
                    '+' => Token::Plus,
                    '-' => Token::Minus,
                    '*' => Token::Multiply,
                    '/' => Token::Divide,
                    '(' => Token::LeftParen,
                    ')' => Token::RightParen,
                    _ => unreachable!(),
                });
            }
            ' ' => {
                if !number_str.is_empty() {
                    if let Ok(num) = number_str.parse::<f64>() {
                        tokens.push(Token::Number(num));
                    }
                    number_str.clear();
                }
            }
            _ => {}
        }
    }

    if !number_str.is_empty() {
        if let Ok(num) = number_str.parse::<f64>() {
            tokens.push(Token::Number(num));
        }
    }

    tokens
}

fn evaluate(tokens: Vec<Token>) -> Result<f64, String> {
    let mut numbers = Vec::new();
    let mut operators = Vec::new();

    for token in tokens {
        match token {
            Token::Number(num) => numbers.push(num),
            Token::Plus | Token::Minus | Token::Multiply | Token::Divide => {
                while !operators.is_empty()
                    && has_precedence(&operators[operators.len() - 1], &token)
                {
                    apply_operator(&mut numbers, operators.pop().unwrap())?;
                }
                operators.push(token);
            }
            _ => return Err("Invalid expression".to_string()),
        }
    }

    while !operators.is_empty() {
        apply_operator(&mut numbers, operators.pop().unwrap())?;
    }

    numbers
        .pop()
        .ok_or_else(|| "Invalid expression".to_string())
}

fn has_precedence(op1: &Token, op2: &Token) -> bool {
    matches!(
        (op1, op2),
        (Token::Multiply | Token::Divide, Token::Plus | Token::Minus)
            | (
                Token::Multiply | Token::Divide,
                Token::Multiply | Token::Divide
            )
            | (Token::Plus | Token::Minus, Token::Plus | Token::Minus)
    )
}

fn apply_operator(numbers: &mut Vec<f64>, operator: Token) -> Result<(), String> {
    if numbers.len() < 2 {
        return Err("Invalid expression".to_string());
    }

    let b = numbers.pop().unwrap();
    let a = numbers.pop().unwrap();

    let result = match operator {
        Token::Plus => a + b,
        Token::Minus => a - b,
        Token::Multiply => a * b,
        Token::Divide => {
            if b == 0.0 {
                return Err("Division by zero".to_string());
            }
            a / b
        }
        _ => return Err("Invalid operator".to_string()),
    };

    numbers.push(result);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tokenize() {
        let tokens = tokenize("2 + 2");
        assert_eq!(
            tokens,
            vec![Token::Number(2.0), Token::Plus, Token::Number(2.0)]
        );
    }

    #[test]
    fn test_evaluate() {
        let result = evaluate(vec![Token::Number(2.0), Token::Plus, Token::Number(2.0)]);
        assert_eq!(result, Ok(4.0));
    }

    #[test]
    fn test_calculator_division() {
        let result = calculate_inner("10 / 2");
        assert_eq!(result, Ok(5.0));
    }

    #[test]
    fn test_calculator_complex_expression() {
        let result = calculate_inner("10 + 2 * 3 - 4 / 2");
        assert_eq!(result, Ok(14.0));
    }
}
