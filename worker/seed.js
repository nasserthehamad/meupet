// Dados de demonstração para a conta de testes (só e-mails em SEED_EMAILS).
// Cria prestadores em Bauru/SP e preenche a conta do tutor com a gata Zuka:
// vacinas, vermífugos, prontuário, receitas, agendamentos, conversas,
// corrida, pedidos e adoções. Pode rodar de novo: usa sempre os mesmos IDs.

import { PHOTOS } from './seed-photos.js';

const base = (p) => `projects/${p}/databases/(default)/documents`;
const api = (p) => `https://firestore.googleapis.com/v1/${base(p)}`;

function val(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(val) } };
  return { mapValue: { fields: fields(v) } };
}
function fields(o) {
  const f = {};
  for (const [k, v] of Object.entries(o)) if (v !== undefined) f[k] = val(v);
  return f;
}
function plain(v) {
  if (!v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(plain);
  if ('mapValue' in v) return plainFields(v.mapValue.fields || {});
  return null;
}
function plainFields(f) {
  const o = {};
  for (const [k, v] of Object.entries(f || {})) o[k] = plain(v);
  return o;
}

export async function seedDemo({ projectId, uid, email, access }) {
  const H = { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' };
  const writes = [];
  const set = (path, data) => writes.push({ update: { name: `${base(projectId)}/${path}`, fields: fields(data) } });
  const patch = (path, data) =>
    writes.push({
      update: { name: `${base(projectId)}/${path}`, fields: fields(data) },
      updateMask: { fieldPaths: Object.keys(data).map((k) => (/^[A-Za-z_][A-Za-z_0-9]*$/.test(k) ? k : '`' + k + '`')) },
    });

  // Horário de Brasília (UTC-3).
  const nowBr = new Date(Date.now() - 3 * 3600 * 1000);
  const day = (d, h, m = 0) => new Date(Date.UTC(nowBr.getUTCFullYear(), nowBr.getUTCMonth(), nowBr.getUTCDate() + d, h + 3, m));
  const yearsAgo = (y, mo = 0) => new Date(Date.UTC(nowBr.getUTCFullYear() - y, nowBr.getUTCMonth() - mo, 10, 15));

  // ---- conta do tutor
  const ur = await fetch(`${api(projectId)}/users/${uid}`, { headers: H });
  const me = ur.ok ? plainFields((await ur.json()).fields) : {};
  const myName = me.name || (email || '').split('@')[0] || 'Tutor';
  const myPhone = me.phone || '';
  const userPatch = {};
  if (!me.city) userPatch.city = 'Bauru';
  if (!me.address) userPatch.address = 'R. Araújo Leite, 10-50 — Vila Santa Tereza';
  if (!me.role) userPatch.role = 'tutor';
  if (Object.keys(userPatch).length) patch(`users/${uid}`, userPatch);

  // ---- prestadores de demonstração (Bauru/SP)
  const P = (id, d) => ({ id, ...d, role: 'prestador', city: 'Bauru', email: '', favorites: [], demo: true });
  const providers = [
    P('demo_vet', {
      name: 'Dra. Adeline Palmerston', businessName: 'Vet Amicão Bauru', photo: PHOTOS.amicao,
      address: 'Av. Getúlio Vargas, 21-45 — Jd. Europa', phone: '(14) 3222-1010', crmv: '12345-SP',
      description: 'Clínica veterinária 24h: consultas, vacinas, exames, odontologia e emergência.',
      categories: ['Veterinário', 'Vacinação', 'Exames', 'Odontologia', 'Nutrição', 'Emergência 24h'], animals: [],
      prices: { Veterinário: 150, Vacinação: 90, Exames: 120, Odontologia: 220, Nutrição: 130, 'Emergência 24h': 280 },
      lat: -22.3355, lng: -49.0605,
    }),
    P('demo_gatos', {
      name: 'Dr. Paulo Mendes', businessName: 'Gatos & Cia Clínica Felina', photo: PHOTOS.adeline,
      address: 'R. Gustavo Maciel, 16-30 — Centro', phone: '(14) 3233-4455', crmv: '23456-SP',
      description: 'Clínica só para gatos: ambiente calmo, sem cães na sala de espera.',
      categories: ['Veterinário', 'Vacinação', 'Exames'], animals: ['Gato'],
      prices: { Veterinário: 140, Vacinação: 85, Exames: 110 },
      lat: -22.3218, lng: -49.0702,
    }),
    P('demo_shop', {
      name: 'Carla Souza', businessName: 'Mania de Bicho', photo: PHOTOS.maniadebicho,
      address: 'R. Batista de Carvalho, 4-33 — Centro', phone: '(14) 3011-2233',
      description: 'Pet shop com banho e tosa, rações, brinquedos e acessórios. Retirada na loja.',
      categories: ['Banho e Tosa', 'Ração', 'Brinquedos', 'Higiene e Limpeza', 'Roupas e Acessórios', 'Cama e Casa'], animals: [],
      prices: { 'Banho e Tosa': 70, Ração: 159.9 },
      lat: -22.3240, lng: -49.0745,
    }),
    P('demo_taxi', {
      name: 'Bruno Lima', businessName: 'Pet Taxi Bauru', photo: PHOTOS.pettaxi,
      address: 'Atende toda Bauru', phone: '(14) 99777-0000',
      description: 'Transporte de pets com caixa de transporte, cinto e ar-condicionado.',
      categories: ['TaxiPet', 'DogWalker'], animals: [],
      prices: { TaxiPet: 15, 'TaxiPet km': 3.5, DogWalker: 30 },
      lat: -22.3300, lng: -49.0810,
    }),
    P('demo_hotel', {
      name: 'Renata Alves', businessName: 'Hotelzinho Patas Felizes', photo: null,
      address: 'R. Rio Branco, 20-10 — Vila América', phone: '(14) 3104-5566',
      description: 'Hotel e creche com monitoramento por câmera e área verde.',
      categories: ['Hotel', 'Creche', 'PetSitter'], animals: ['Cachorro', 'Gato'],
      prices: { Hotel: 95, Creche: 70, PetSitter: 60 },
      lat: -22.3452, lng: -49.0520,
    }),
    P('demo_adestra', {
      name: 'Marcos Ribeiro', businessName: 'Adestra Bauru', photo: null,
      address: 'Av. Nações Unidas, 30-15 — Vila Noemy', phone: '(14) 99666-1212',
      description: 'Adestramento positivo e passeios em grupo.',
      categories: ['Adestramento', 'DogWalker'], animals: ['Cachorro'],
      prices: { Adestramento: 120, DogWalker: 35 },
      lat: -22.3105, lng: -49.0950,
    }),
    P('demo_farma', {
      name: 'Juliana Prado', businessName: 'VetFarma Bauru', photo: null,
      address: 'R. Primeiro de Agosto, 7-40 — Centro', phone: '(14) 3222-7788',
      description: 'Farmácia veterinária com manipulação e suplementos.',
      categories: ['Farmácia', 'Suplementos'], animals: [],
      prices: { Farmácia: 25 },
      lat: -22.3260, lng: -49.0690,
    }),
    P('demo_lab', {
      name: 'Dra. Sofia Lima', businessName: 'LabVet Diagnósticos', photo: null,
      address: 'Av. Duque de Caxias, 12-60 — Vila Cidade Universitária', phone: '(14) 3011-9090', crmv: '34567-SP',
      description: 'Laboratório veterinário: hemograma, bioquímicos e imagem.',
      categories: ['Exames'], animals: [],
      prices: { Exames: 95 },
      lat: -22.3380, lng: -49.0780,
    }),
  ];
  for (const p of providers) {
    const { id, ...data } = p;
    set(`users/${id}`, { ...data, createdAt: day(-60, 9) });
  }
  const prov = Object.fromEntries(providers.map((p) => [p.id, p]));

  // ---- a gata Zuka (usa a do tutor, se já existir)
  const q = await fetch(`${api(projectId)}:runQuery`, {
    method: 'POST',
    headers: H,
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'pets' }],
        where: { fieldFilter: { field: { fieldPath: 'ownerId' }, op: 'EQUAL', value: { stringValue: uid } } },
      },
    }),
  });
  const pets = q.ok ? (await q.json()).filter((r) => r.document).map((r) => ({ id: r.document.name.split('/').pop(), ...plainFields(r.document.fields) })) : [];
  let zuka = pets.find((p) => (p.name || '').trim().toLowerCase() === 'zuka');
  const zukaId = zuka ? zuka.id : `demo_zuka_${uid}`;
  const zukaFill = {
    ownerId: uid,
    ownerName: myName,
    name: 'Zuka',
    species: 'Gato',
    breed: 'SRD (sem raça definida)',
    sex: 'F',
    birthDate: yearsAgo(2, 7),
    weight: '4,2',
    height: '25',
    photo: PHOTOS.zuka,
    allergies: 'Dipirona',
    treatments: '',
    food: 'Ração Premium Gatos Castrados + sachê à noite',
    plan: 'Meu Pet Cute | Padrão',
    code: 'SP | 14 03 2024 00127',
  };
  if (!zuka) {
    set(`pets/${zukaId}`, { ...zukaFill, createdAt: day(-200, 10) });
    zuka = { id: zukaId, ...zukaFill };
  } else {
    const fill = {};
    for (const [k, v] of Object.entries(zukaFill)) {
      const cur = zuka[k];
      if (cur === null || cur === undefined || cur === '' || (k === 'species' && cur !== 'Gato')) fill[k] = v;
    }
    if (Object.keys(fill).length) patch(`pets/${zukaId}`, fill);
    zuka = { ...zukaFill, ...Object.fromEntries(Object.entries(zuka).filter(([, v]) => v !== null && v !== '')) };
  }
  const zukaPhoto = zuka.photo || PHOTOS.zuka;
  const pet = `pets/${zukaId}`;
  const vet = prov.demo_vet;
  const vetName = vet.businessName;

  // Vacinas, vermífugos/antipulgas, prontuário e avaliação do comportamento.
  set(`${pet}/vaccines/demo_v4`, { name: 'V4 felina (quádrupla)', vet: vetName, date: day(-210, 10), nextDate: day(155, 10) });
  set(`${pet}/vaccines/demo_raiva`, { name: 'Antirrábica', vet: vetName, date: day(-180, 10), nextDate: day(185, 10) });
  set(`${pet}/vaccines/demo_felv`, { name: 'FeLV (leucemia felina)', vet: prov.demo_gatos.businessName, date: day(-40, 15), nextDate: day(6, 9) });
  set(`${pet}/parasites/demo_revolution`, { product: 'Revolution Gatos (pipeta)', weight: '4,2', date: day(-25, 19), nextDate: day(5, 19) });
  set(`${pet}/parasites/demo_drontal`, { product: 'Drontal Gatos', weight: '4,0', date: day(-95, 19), nextDate: day(-5, 19) });
  set(`${pet}/records/demo_c1`, { type: 'consulta', title: 'Consulta de rotina — check-up', professional: vet.name, crm: vet.crmv, date: day(-30, 10), notes: 'Saudável. Peso ideal. Reforçar escovação dos dentes.' });
  set(`${pet}/records/demo_r1`, { type: 'receita', title: 'Suplemento para pelagem — 30 dias', professional: vet.name, crm: vet.crmv, date: day(-30, 10, 40), notes: '1 dose ao dia misturada no sachê.' });
  set(`${pet}/records/demo_e1`, { type: 'exame', title: 'Hemograma completo', professional: prov.demo_lab.businessName, date: day(-28, 8), notes: 'Normal' });
  set(`${pet}/records/demo_e2`, { type: 'exame', title: 'Função renal (ureia e creatinina)', professional: prov.demo_lab.businessName, date: day(-28, 8, 10), notes: 'Normal' });
  set(`${pet}/records/demo_c2`, { type: 'consulta', title: 'Castração', professional: vet.name, crm: vet.crmv, date: day(-400, 8), notes: 'Procedimento sem intercorrências.' });
  set(`${pet}/behavior/demo_b1`, { providerId: 'demo_shop', providerName: 'Mania de Bicho', stars: 4, text: 'Desconfiada no começo, depois fica calma. Não gosta de secador.', createdAt: day(-10, 16) });
  set(`${pet}/behavior/demo_b2`, { providerId: 'demo_taxi', providerName: 'Pet Taxi Bauru', stars: 5, text: 'Tranquila na caixa de transporte. Miou só na partida.', createdAt: day(-12, 18) });

  // ---- agendamentos
  const A = (id, prv, service, when, status, extra = {}) =>
    set(`appointments/demo_${uid}_${id}`, {
      tutorId: uid, tutorName: myName, petId: zukaId, petName: 'Zuka', species: 'Gato', petPhoto: zukaPhoto,
      providerId: prv.id, providerName: prv.businessName, service, dateTime: when, status,
      notes: '', taxiPet: false, address: '', createdAt: day(-3, 12), ...extra,
    });
  A('a1', vet, 'Veterinário', day(1, 10), 'confirmado', { notes: 'Retorno do check-up' });
  A('a2', prov.demo_shop, 'Banho e Tosa', day(3, 14, 30), 'pendente', { notes: 'Banho com hidratação', taxiPet: true, address: me.address || userPatch.address });
  A('a3', prov.demo_gatos, 'Vacinação', day(6, 9), 'confirmado', { notes: 'Reforço FeLV' });
  A('a4', vet, 'Veterinário', day(-30, 10), 'concluido', { notes: 'Check-up anual' });
  A('a5', prov.demo_shop, 'Banho e Tosa', day(-10, 15), 'concluido');
  A('a6', prov.demo_lab, 'Exames', day(-28, 8), 'concluido', { notes: 'Hemograma e função renal' });

  // ---- receitas e pedido de exame
  const rxBase = {
    petId: zukaId, petName: 'Zuka', petSpecies: 'Gato', petBreed: 'SRD', petAge: '2 anos', petWeight: '4,2', petHeight: '25',
    ownerId: uid, ownerName: myName, providerId: vet.id, providerName: vetName, professional: vet.name, crmv: vet.crmv, notes: '',
  };
  set(`prescriptions/demo_${uid}_rx1`, {
    ...rxBase, kind: 'receita', exams: [],
    items: [
      { name: 'Suplemento Ômega 3 para gatos', route: 'Oral', use: '1 dose ao dia misturada no sachê, por 30 dias.' },
      { name: 'Pasta de malte', route: 'Oral', use: '2 cm, 3 vezes por semana, para bolas de pelo.' },
    ],
    consultaDate: day(-30, 10), returnDate: day(1, 10), signedAt: day(-30, 10, 40), code: 'MP-8F3K-2QZ7', seen: true, createdAt: day(-30, 10, 40),
  });
  set(`prescriptions/demo_${uid}_ex1`, {
    ...rxBase, kind: 'exame', items: [], exams: ['Ultrassom abdominal', 'Urinálise (urina tipo I)'], notes: 'Controle de rotina',
    consultaDate: day(-2, 11), returnDate: null, signedAt: day(-2, 11, 20), code: 'MP-4T9W-7HC2', seen: false, createdAt: day(-2, 11, 20),
  });
  set(`prescriptions/demo_${uid}_rx2`, {
    ...rxBase, kind: 'receita', exams: [],
    items: [{ name: 'Antialérgico (manipulado)', route: 'Oral', use: '1 cápsula a cada 24h por 7 dias.' }],
    consultaDate: day(-2, 11), returnDate: day(12, 11), signedAt: day(-2, 11, 25), code: 'MP-6N2D-1KX8', seen: false, createdAt: day(-2, 11, 25),
  });

  // ---- avaliações dos prestadores
  const R = (pid, tid, tname, stars, text, d) =>
    set(`reviews/${pid}_${tid}`, { providerId: pid, tutorId: tid, tutorName: tname, stars, text, updatedAt: day(d, 12) });
  R('demo_vet', uid, myName, 5, 'Atendimento ótimo com a Zuka, muito cuidadosos!', -29);
  R('demo_vet', 'demo_t1', 'Marcos Lima', 5, 'Salvaram minha gata de madrugada. Recomendo demais.', -40);
  R('demo_vet', 'demo_t2', 'Ana Paula', 4, 'Ótimos profissionais, só demorou um pouco.', -15);
  R('demo_gatos', 'demo_t3', 'Fernanda Rocha', 5, 'Minha gata ficou calma o tempo todo. Ambiente perfeito.', -20);
  R('demo_gatos', 'demo_t1', 'Marcos Lima', 5, 'Atendimento muito carinhoso.', -50);
  R('demo_shop', uid, myName, 4, 'Banho caprichado, a Zuka voltou cheirosa.', -9);
  R('demo_shop', 'demo_t2', 'Ana Paula', 5, 'Preço justo e entrega rápida.', -22);
  R('demo_taxi', uid, myName, 5, 'Pontual e cuidadoso com a Zuka.', -11);
  R('demo_taxi', 'demo_t4', 'João Pedro', 4, 'Chegou rápido, carro limpo.', -35);
  R('demo_hotel', 'demo_t4', 'João Pedro', 5, 'Deixei meu cachorro uma semana, voltou feliz.', -60);
  R('demo_adestra', 'demo_t3', 'Fernanda Rocha', 4, 'Em 4 aulas meu cão já anda sem puxar.', -18);
  R('demo_lab', 'demo_t2', 'Ana Paula', 5, 'Resultado no mesmo dia.', -27);

  // ---- conversas (a última do vet fica sem ler, para testar o sino)
  const chatId = (a, b) => [a, b].sort().join('_');
  const vetChat = chatId(uid, 'demo_vet');
  set(`chats/${vetChat}`, {
    participants: [uid, 'demo_vet'].sort(), names: { [uid]: myName, demo_vet: vetName },
    lastMessage: 'Já deixei o pedido de exames no app. Qualquer dúvida é só chamar!', lastSender: 'demo_vet',
    updatedAt: day(-2, 11, 30), readBy: { demo_vet: true },
  });
  const vm = [
    [uid, 'Oi, a Zuka está se coçando bastante desde ontem. Consegue ver hoje?', day(-2, 9, 10)],
    ['demo_vet', 'Oi! Consigo sim, pode trazer às 11h.', day(-2, 9, 14)],
    [uid, 'Combinado, obrigada! 🐱', day(-2, 9, 15)],
    ['demo_vet', 'Já deixei o pedido de exames no app. Qualquer dúvida é só chamar!', day(-2, 11, 30)],
  ];
  vm.forEach(([s, t, d], i) => set(`chats/${vetChat}/messages/demo_${i}`, { senderId: s, text: t, createdAt: d }));
  const shopChat = chatId(uid, 'demo_shop');
  set(`chats/${shopChat}`, {
    participants: [uid, 'demo_shop'].sort(), names: { [uid]: myName, demo_shop: 'Mania de Bicho' },
    lastMessage: 'Perfeito, até lá! 😊', lastSender: uid, updatedAt: day(-1, 17, 5), readBy: { [uid]: true, demo_shop: true },
  });
  const sm = [
    ['demo_shop', 'Oi! Seu pedido já está separado para retirada amanhã.', day(-1, 17, 0)],
    [uid, 'Perfeito, até lá! 😊', day(-1, 17, 5)],
  ];
  sm.forEach(([s, t, d], i) => set(`chats/${shopChat}/messages/demo_${i}`, { senderId: s, text: t, createdAt: d }));

  // ---- corrida concluída do TaxiPet
  set(`rides/demo_${uid}_r1`, {
    tutorId: uid, tutorName: myName, tutorPhone: myPhone, petId: zukaId, petName: 'Zuka', petSpecies: 'Gato', petPhoto: zukaPhoto,
    driverId: 'demo_taxi', driverName: 'Pet Taxi Bauru', driverPhone: '(14) 99777-0000',
    pickup: 'R. Araújo Leite, 10-50, Vila Santa Tereza, Bauru, SP', destination: 'Vet Amicão Bauru, Av. Getúlio Vargas, 21-45, Bauru, SP',
    pickupLat: -22.3283, pickupLng: -49.0742, destLat: -22.3355, destLng: -49.0605, km: 2.4, minutes: 8, price: 23.4,
    city: 'Bauru', when: day(-12, 17, 30), notes: 'Caixa de transporte pequena.', status: 'concluida',
    createdAt: day(-12, 17, 20), updatedAt: day(-12, 18, 0),
  });

  // ---- loja: produtos e pedidos
  const products = [
    ['racao', 'Ração Premium Gatos Castrados 3kg', 119.9, 'Ração'],
    ['sache', 'Sachê Gatos Adultos (caixa 12un)', 39.9, 'Ração'],
    ['petisco', 'Petisco Bifinho de Frango 65g', 12.5, 'Ração'],
    ['arranhador', 'Arranhador Torre 60cm', 149.0, 'Brinquedos'],
    ['varinha', 'Varinha com Penas', 19.9, 'Brinquedos'],
    ['areia', 'Areia Sanitária Biodegradável 4kg', 34.9, 'Higiene e Limpeza'],
    ['shampoo', 'Shampoo Neutro 500ml', 32.0, 'Higiene e Limpeza'],
    ['coleira', 'Coleira Peitoral Ajustável', 59.9, 'Roupas e Acessórios'],
    ['cama', 'Cama Iglu para Gatos', 129.0, 'Cama e Casa'],
  ];
  for (const [k, name, price, category] of products) {
    set(`products/demo_${k}`, { storeId: 'demo_shop', name, price, category, photoUrl: '', description: '', available: true });
  }
  set(`orders/demo_${uid}_o1`, {
    storeId: 'demo_shop', storeName: 'Mania de Bicho', tutorId: uid, tutorName: myName, tutorPhone: myPhone, tutorPhoto: me.photo || null,
    items: [
      { productId: 'demo_racao', name: products[0][1], price: 119.9, qty: 1 },
      { productId: 'demo_varinha', name: products[4][1], price: 19.9, qty: 1 },
    ],
    total: 139.8, pickupName: myName, pickupDate: day(1, 17), notes: '', nfe: 'NB3021', status: 'pronto', createdAt: day(-1, 16, 40),
  });
  set(`orders/demo_${uid}_o2`, {
    storeId: 'demo_shop', storeName: 'Mania de Bicho', tutorId: uid, tutorName: myName, tutorPhone: myPhone, tutorPhoto: me.photo || null,
    items: [{ productId: 'demo_areia', name: products[5][1], price: 34.9, qty: 2 }],
    total: 69.8, pickupName: myName, pickupDate: day(-15, 10), notes: '', nfe: 'NB2987', status: 'concluido', createdAt: day(-16, 9),
  });

  // ---- adoção em Bauru
  const adopt = [
    ['zeca', 'Zeca', 'Cachorro', '2 anos', 'M'], ['amarelo', 'Amarelo', 'Cachorro', '1,5 anos', 'M'], ['fofs', 'Fofs', 'Gato', '7 meses', 'F'],
    ['bella', 'Bella', 'Gato', '2 meses', 'F'], ['bilu', 'Bilu', 'Cachorro', '4 anos', 'M'], ['boris', 'Boris', 'Aves', '3 anos', 'M'],
  ];
  for (const [k, name, species, age, sex] of adopt) {
    set(`adoptions/demo_${k}`, {
      name, species, age, sex, photo: PHOTOS[k], description: 'Dócil, vacinado e castrado. Adora carinho.',
      city: 'Bauru', postedBy: 'demo_shop', postedByName: 'Mania de Bicho', status: 'disponivel', createdAt: day(-5, 10),
    });
  }

  // Grava tudo de uma vez.
  for (let i = 0; i < writes.length; i += 400) {
    const r = await fetch(`${api(projectId)}:commit`, { method: 'POST', headers: H, body: JSON.stringify({ writes: writes.slice(i, i + 400) }) });
    if (!r.ok) throw new Error(`Firestore ${r.status}: ${(await r.text()).slice(0, 300)}`);
  }
  return { writes: writes.length, providers: providers.length, petId: zukaId, petCreated: !pets.some((p) => p.id === zukaId) };
}
