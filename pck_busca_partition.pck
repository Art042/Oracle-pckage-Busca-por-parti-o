/*
Oracle Package de Busca por particao, nesse caso a particao de data por periodo de inicio e fim
A busca por particao geralmente é usada em um banco com um grande volumes de Informacao.
Nesse exemplo temos um banco relacional dividido em particoes com Notas fiscais de uma loja. 
*/

--------------------------Header--------------------------------------------------------------------
create or replace package pck_busca_por_particao is

    procedure execucao(p_id_vendedor         in number,
                        p_cpf_vendedor      in number,
                        p_id_cliente        in number,                
                        p_cpf_cliente       in number,
                        p_periodo_inicial   in varchar2,
                        p_periodo_final     in varchar2,
                        p_cursor            out t_cursor, 
                        p_erro              out varchar2);

end pck_busca_por_particao;
----------------------------------------------------Body-------------------------------------------

create or replace package body pck_busca_por_particao is --Retorna um lote de notas fiscais salvas


    procedure execucao(p_id_vendedor         in number,
                        p_cpf_vendedor      in number,
                        p_id_cliente        in number,                
                        p_cpf_cliente       in number,
                        p_periodo_inicial   in varchar2,
                        p_periodo_final     in varchar2,
                        p_cursor            out t_cursor, 
                        p_erro              out varchar2) is



    v_query    varchar2(1500);     
    v_query_partition varchar2(1500);
  
    v_aux  number(4);
  
    v_per_ini number(6);
    v_per_fim number(6);

    erro_negocio exception; 
  
    begin
        /*Aqui o erro é usado para fazer o controle de buscas 
        Como o volume de dados eh grande, retornamos o erro para evitar uma pesquisa muito demorada*/
        p_erro        := 'N';
        
        execute immediate 'alter session set nls_date_format = ''dd/mm/yyyy''';
    
        v_per_ini := to_char(to_date(p_periodo_inicial, 'dd/mm/yyyy'), 'yyyymm');
        v_per_fim := to_char(to_date(p_periodo_final, 'dd/mm/yyyy'), 'yyyymm');
        
        if v_per_ini <> v_per_fim then
            v_query_partition := ' ';
        elsif (v_per_ini is null and v_per_fim is null) then
            raise erro_negocio; -- Deve ser informado um periodo de tempo.
        elsif v_per_ini is null then -- Pode ser usado para determinar o mes inicial a partir do mes final
            v_per_ini:= to_char(add_months(to_date(p_periodo_final, 'dd/mm/yyyy'),-1),'yyyymm');
        elsif v_per_fim is null then -- Pode ser usado para determinar o mes inicial a partir do mes final
            v_per_fim:= to_char(add_months(to_date(p_periodo_inicial, 'dd/mm/yyyy'),1),'yyyymm');        
        else
            v_query_partition := ' partition(P_' || to_char(v_per_ini) || ') '; --Particao Retorna 1 mes
        end if;
            v_aux := TO_NUMBER(v_per_fim) - TO_NUMBER(v_per_ini);
                
    /* Controle de Tempo da Particao, aqui esta configurado para 1 mes ou menos, e data do fim nao deve ser menor que a data do inicio */  
        if v_aux > 1 or v_aux < 0 then
            raise erro_negocio; -- Periodo informado nao pode ser superior a 01 mes.
        end if;
        
        v_query := '
            SELECT 
            NUM_NOTA,
            CPF_VENDEDOR,
            ID_VENDEDOR,
            NOME_VENDEDOR,
            CPF_CLIENTE,
            ID_CLIENTE,
            NOME_CLIENTE,
            decode(TDE_TPOPER,''0'',''Entrada'',''1'',''SAIDA'') OPERACAO,
            ST.STATUS,
            to_char(TDE_DTEMISSAO, ''dd/mm/yyyy'') DATA_EMISSAO
            from  tab_notas_fiscais ' || v_query_partition || ' s, tab_info_loja st
            where s.campo_1 = st.campo_11
            ';
        
        if p_periodo_inicial is not null and p_periodo_final is not null then
        v_query := v_query || ' and to_char(TDE_DTEMISSAO,''dd/mm/yyyy'') BETWEEN
            to_date(''' || p_periodo_inicial ||
                    ''',''dd/mm/yyyy'') AND
                to_date(''' || p_periodo_final ||
                    ''',''dd/mm/yyyy'')';
        end if;
        
    if p_id_vendedor  is not null then
        v_sq    l := v_query || ' ID_VENDEDOR = ' || p_id_vendedor   ;
    end If; 

    if p_id_cliente is not null then
        v_query := v_query || ' and ID_CLIENTE = ' || p_id_clien        te;
    end if;

    if p_cpf_vendedor is not null then
        v_query := v_query || ' and CPF_VENDEDOR = ' || p_cpf_vendedor;
        end if; 
        
        if p_cpf_cliente is not null then
        v_query := v_query || ' and CPF_CLIENTE = ' || p_cpf_cliente;
        end if;
        
        
        open p_cursor for v_query;
        
    exception
        when erro_negocio then
        open p_cursor for
            select 0 from dual where 1 = 2;
        p_erro := 'S';
        
        end;
end;
