`timescale 1ns / 1ps

module tb_genius_game;

  // Sinais do clock e controle
  logic clk = 0;
  logic reset = 0;
  logic botao_start = 0;
  logic [1:0] entrada_jogador = 0;
  logic partida_led;
  logic [3:0] led_seq;
  logic [6:0] display;
  logic win;
  logic defeat;

  // Clock: 200 MHz (5 ns de período)
  always #2.5 clk = ~clk;

  // DUT (Device Under Test)
  top_genius_game dut (
    .clk(clk),
    .reset(reset),
    .botao_start(botao_start),
    .entrada_jogador(entrada_jogador),
    .partida_led(partida_led),
    .led_seq(led_seq),
    .display(display),
    .win(win),
    .defeat(defeat)
  );

  initial begin
    $display("=== Iniciando Simulação ===");
    $monitor("T=%0t | Estado: %s | Score: %0d | Win: %b | Defeat: %b", 
             $time, dut.controller.current_state.name(), dut.score_manager.score_atual, win, defeat);
    
    // Reset inicial
    reset = 1;
    #20;
    reset = 0;
    
    // Inicia o jogo
    botao_start = 1;
    #10;
    botao_start = 0;
    
    // Aguarda a sequência ser gerada
    repeat (50) @(posedge clk);
    
    // Simula TODAS as 8 entradas corretas
    for (int i = 0; i < 8; i++) begin
      wait (dut.controller.current_state == dut.controller.GetPlayerInput);
      #1;
      $display("Sequência[%0d]: %b", i, dut.register_bank.sequencia_out[i]);
      entrada_jogador = dut.register_bank.sequencia_out[i];  // Jogador acerta a entrada
      @(posedge clk);
      #5;
      entrada_jogador = 2'b00;  // Libera o botão
    end
    
    // Aguarda o estado final (Victory ou Defeat)
    repeat (100) @(posedge clk);  // Ajuste conforme necessário
    
    // Verifica resultado
    if (win)
      $display("Jogador venceu!");
    else if (defeat)
      $display("Jogador perdeu!");
    else
      $display("Teste incompleto. Estado atual: %s", dut.controller.current_state.name());
      
    $finish;
  end
endmodule