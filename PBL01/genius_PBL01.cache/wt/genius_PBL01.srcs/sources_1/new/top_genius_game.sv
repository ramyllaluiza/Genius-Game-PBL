`timescale 1ns / 1ps

// Módulo GNR (Gerador de Número Aleatório)
module GNR (
  input      logic clk,
  input      logic reset,
  input      logic enable,
  output     logic [1:0] random_out
);

  logic [3:0] lfsr;
  logic feedback;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      lfsr <= 4'b1001;  // Valor inicial arbitrário
      random_out <= 2'b00;
    end else begin
      feedback = lfsr[3] ^ lfsr[2];  // Polinômio x^4 + x^3 + 1
      lfsr <= {lfsr[2:0], feedback};
      random_out <= lfsr[3:2];  // Mapeia 2 bits para 4 cores
    end
  end
endmodule

// Módulo RegisterBank (Banco de Registradores)
module RegisterBank (
  input      logic clk,
  input      logic reset,
  input      logic sequencia_write,
  input      logic [1:0] cor_input,
  output     logic [1:0] sequencia_out [0:7],  // Saída da sequência
  output     logic [3:0] indice_sequencia      // Saída do índice
);

  logic [3:0] indice;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      sequencia_out <= '{default: 2'b00};
      indice <= 4'd0;
    end else if (sequencia_write) begin
      sequencia_out[indice] <= cor_input;
      indice <= indice + 1;
    end
  end

  assign indice_sequencia = indice;
endmodule

// Módulo ScoreManager (Gerenciador de Pontuação)
module ScoreManager (
  input      logic clk,
  input      logic reset,
  input      logic incrementar_score,
  output     logic [7:0] score_atual,
  output     logic [6:0] display_out
);

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      score_atual <= 8'd0;
    end else if (incrementar_score) begin
      score_atual <= score_atual + 1;
    end
  end

  always_comb begin
    case (score_atual % 10)
      0: display_out = 7'b1000000;
      1: display_out = 7'b1111001;
      2: display_out = 7'b0100100;
      3: display_out = 7'b0110000;
      4: display_out = 7'b0011001;
      5: display_out = 7'b0010010;
      6: display_out = 7'b0000010;
      7: display_out = 7'b1111000;
      8: display_out = 7'b0000000;
      9: display_out = 7'b0010000;
      default: display_out = 7'b1111111;
    endcase
  end
endmodule

// Módulo Controller (FSM Principal)
module Controller (
  input      logic clk,
  input      logic reset,
  input      logic botao_start,
  input      logic [1:0] entrada_jogador,
  input      logic [1:0] numero_aleatorio,
  input      logic [7:0] score_atual,
  input      logic [1:0] sequencia_out [0:7],
  input      logic [3:0] indice_sequencia,
  output     logic [3:0] sinais_de_controle,
  output     logic partida_led,
  output     logic [3:0] led_seq,
  output     logic win,
  output     logic defeat
);

  typedef enum logic [3:0] {
    Off, IDLE, GNR, MatrixValues, ShowSequence, GetPlayerInput, Comparison, Defeat, Evaluate, Victory
  } state_t;

  state_t current_state, next_state;
  logic [3:0] i;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      current_state <= Off;
      i <= 4'd0;
    end else begin
      current_state <= next_state;
      if (current_state == ShowSequence && i < indice_sequencia)
        i <= i + 1;
      else if (current_state == ShowSequence && i == indice_sequencia)
        i <= 4'd0;
    end
  end

  always_comb begin
    next_state = current_state;
    sinais_de_controle = 4'b0000;
    partida_led = 1'b0;
    led_seq = 4'b0000;
    win = 1'b0;
    defeat = 1'b0;

    case (current_state)
      Off: if (botao_start) next_state = IDLE;
      IDLE: if (botao_start) next_state = GNR;
      GNR: begin
        sinais_de_controle[0] = 1;
        next_state = MatrixValues;
      end
      MatrixValues: begin
        sinais_de_controle[1] = 1;
        next_state = ShowSequence;
      end
      ShowSequence: begin
        partida_led = 1;
        led_seq = {sequencia_out[i], sequencia_out[i]};  // Mapeamento 2->4 bits
        if (i == indice_sequencia) begin
          next_state = GetPlayerInput;
        end
      end
      GetPlayerInput: begin
        if (entrada_jogador != 2'b00) next_state = Comparison;
      end
      Comparison: begin
        if (entrada_jogador == sequencia_out[i]) begin
          sinais_de_controle[2] = 1;
          next_state = Evaluate;
        end else begin
          next_state = Defeat;
        end
      end
      Defeat: begin
        defeat = 1;
        led_seq = 4'b1111;
        sinais_de_controle[3] = 1;  // Sinal de reset do ScoreManager
        next_state = IDLE;
      end
      Evaluate: begin
        if (indice_sequencia == 4'd8) next_state = Victory;
        else next_state = GNR;
      end
      Victory: begin
        win = 1;
        led_seq = 4'b1010;
        next_state = IDLE;
      end
      default: next_state = Off;
    endcase
  end
endmodule

// Módulo Top Level
module top_genius_game (
  input      logic clk,
  input      logic reset,
  input      logic botao_start,
  input      logic [1:0] entrada_jogador,
  output     logic partida_led,
  output     logic [3:0] led_seq,
  output     logic [6:0] display,
  output     logic win,
  output     logic defeat
);

  logic [1:0] numero_aleatorio;
  logic [7:0] score_atual;
  logic [3:0] sinais_de_controle;
  logic [1:0] sequencia_out [0:7];
  logic [3:0] indice_sequencia;

  GNR gnr (
    .clk(clk),
    .reset(reset),
    .enable(sinais_de_controle[0]),
    .random_out(numero_aleatorio)
  );

  RegisterBank register_bank (
    .clk(clk),
    .reset(reset),
    .sequencia_write(sinais_de_controle[1]),
    .cor_input(numero_aleatorio),
    .sequencia_out(sequencia_out),
    .indice_sequencia(indice_sequencia)
  );

  ScoreManager score_manager (
    .clk(clk),
    .reset(reset || sinais_de_controle[3]),
    .incrementar_score(sinais_de_controle[2]),
    .score_atual(score_atual),
    .display_out(display)
  );

  Controller controller (
    .clk(clk),
    .reset(reset),
    .botao_start(botao_start),
    .entrada_jogador(entrada_jogador),
    .numero_aleatorio(numero_aleatorio),
    .score_atual(score_atual),
    .sequencia_out(sequencia_out),
    .indice_sequencia(indice_sequencia),
    .sinais_de_controle(sinais_de_controle),
    .partida_led(partida_led),
    .led_seq(led_seq),
    .win(win),
    .defeat(defeat)
  );
endmodule